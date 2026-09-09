#!/usr/bin/env python3
# Copyright (C) 2026 Rootiest
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Comprehensive unit tests for scripts/sync-labels.py with network isolation."""

import io
import json
import os
import socket
import sys
import tempfile
import unittest
import warnings
from pathlib import Path
from unittest.mock import MagicMock, patch, call
import urllib.error
import urllib.request
import importlib.util

# Load scripts/sync-labels.py via importlib (handling the hyphen in filename)
_script_path = Path(__file__).resolve().parent.parent / "scripts" / "sync-labels.py"
_spec = importlib.util.spec_from_file_location("sync_labels", _script_path)
sl = importlib.util.module_from_spec(_spec)
sys.modules["sync_labels"] = sl
_spec.loader.exec_module(sl)


def _make_http_error(url, code, msg, headers, body_bytes):
    fp = io.BytesIO(body_bytes)
    return urllib.error.HTTPError(url, code, msg, headers, fp)


class TestRequestNetworkDrop(unittest.TestCase):
    """Edge cases for complete network drop and connection failures."""

    @patch("urllib.request.urlopen")
    def test_request_connection_refused(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError(
            ConnectionRefusedError(111, "Connection refused")
        )
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("Connection refused", str(ctx.exception))

    @patch("urllib.request.urlopen")
    def test_request_dns_resolution_failure(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError(
            socket.gaierror(-2, "Name or service not known")
        )
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://nonexistent.invalid/test")
        self.assertIn("Name or service not known", str(ctx.exception))

    @patch("urllib.request.urlopen")
    def test_request_network_unreachable(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError(
            OSError(101, "Network is unreachable")
        )
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("Network is unreachable", str(ctx.exception))


class TestRequestTimeouts(unittest.TestCase):
    """Edge cases for slow or hung connections and timeouts."""

    @patch("urllib.request.urlopen")
    def test_request_socket_timeout(self, mock_urlopen):
        mock_urlopen.side_effect = urllib.error.URLError(
            socket.timeout("The read operation timed out")
        )
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("timed out", str(ctx.exception))

    @patch("urllib.request.urlopen")
    def test_request_timeout_parameter_passed(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b'{"ok": true}'
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        mock_urlopen.return_value = mock_resp

        sl.request("https://api.github.com/test")
        mock_urlopen.assert_called_once()
        _, kwargs = mock_urlopen.call_args
        self.assertEqual(kwargs.get("timeout"), sl.TIMEOUT)


class TestRequestHttpCodes(unittest.TestCase):
    """Edge cases for HTTP 4xx and 5xx responses, rate limiting, and errors."""

    @patch("urllib.request.urlopen")
    def test_request_http_401_unauthorized(self, mock_urlopen):
        err = _make_http_error(
            "https://api.github.com/test",
            401,
            "Unauthorized",
            {},
            b'{"message": "Bad credentials"}',
        )
        mock_urlopen.side_effect = err
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test", token="invalid")
        self.assertIn("HTTP 401", str(ctx.exception))
        self.assertIn("Bad credentials", str(ctx.exception))
        err.close()

    @patch("urllib.request.urlopen")
    def test_request_http_403_rate_limit(self, mock_urlopen):
        err = _make_http_error(
            "https://api.github.com/test",
            403,
            "Forbidden",
            {"X-RateLimit-Remaining": "0"},
            b'{"message": "API rate limit exceeded for user"}',
        )
        mock_urlopen.side_effect = err
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("HTTP 403", str(ctx.exception))
        self.assertIn("rate limit exceeded", str(ctx.exception))
        err.close()

    @patch("urllib.request.urlopen")
    def test_request_http_404_not_found(self, mock_urlopen):
        err = _make_http_error(
            "https://api.github.com/test",
            404,
            "Not Found",
            {},
            b'{"message": "Not Found"}',
        )
        mock_urlopen.side_effect = err
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("HTTP 404", str(ctx.exception))
        err.close()

    @patch("urllib.request.urlopen")
    def test_request_http_500_server_error(self, mock_urlopen):
        err = _make_http_error(
            "https://api.github.com/test",
            500,
            "Internal Server Error",
            {},
            b"Internal Server Error",
        )
        mock_urlopen.side_effect = err
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("HTTP 500", str(ctx.exception))
        err.close()

    @patch("urllib.request.urlopen")
    def test_request_http_502_bad_gateway(self, mock_urlopen):
        err = _make_http_error(
            "https://api.github.com/test",
            502,
            "Bad Gateway",
            {},
            b"<html><body>502 Bad Gateway</body></html>",
        )
        mock_urlopen.side_effect = err
        with self.assertRaises(sl.SyncError) as ctx:
            sl.request("https://api.github.com/test")
        self.assertIn("HTTP 502", str(ctx.exception))
        err.close()


class TestRequestPayloads(unittest.TestCase):
    """Edge cases for payloads, parsing, and request formatting."""

    @patch("urllib.request.urlopen")
    def test_request_valid_json(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b'[{"name": "Kind/Bug", "color": "ee0701"}]'
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        mock_urlopen.return_value = mock_resp

        res = sl.request("https://api.github.com/test")
        self.assertEqual(res, [{"name": "Kind/Bug", "color": "ee0701"}])

    @patch("urllib.request.urlopen")
    def test_request_empty_body_204(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b""
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        mock_urlopen.return_value = mock_resp

        res = sl.request("https://api.github.com/test", method="DELETE")
        self.assertIsNone(res)

    @patch("urllib.request.urlopen")
    def test_request_headers_and_auth(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b"{}"
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        mock_urlopen.return_value = mock_resp

        sl.request(
            "https://api.github.com/test",
            token="secret_token",
            method="POST",
            payload={"name": "test"},
        )
        req = mock_urlopen.call_args[0][0]
        self.assertEqual(req.get_header("Authorization"), "Bearer secret_token")
        self.assertEqual(req.get_header("Accept"), "application/json")
        self.assertEqual(req.get_header("Content-type"), "application/json")
        self.assertEqual(req.get_method(), "POST")
        self.assertEqual(req.data, b'{"name": "test"}')

    @patch("urllib.request.urlopen")
    def test_request_corrupted_json_payload(self, mock_urlopen):
        mock_resp = MagicMock()
        mock_resp.read.return_value = b'{"name": "broken", invalid_json'
        mock_resp.__enter__.return_value = mock_resp
        mock_resp.__exit__.return_value = None
        mock_urlopen.return_value = mock_resp

        with self.assertRaises(json.JSONDecodeError):
            sl.request("https://api.github.com/test")


class TestPaginate(unittest.TestCase):
    """Edge cases for pagination across API responses."""

    @patch("sync_labels.request")
    def test_paginate_single_page(self, mock_req):
        mock_req.return_value = [{"name": "A"}, {"name": "B"}]
        res = sl.paginate("https://api.test?page={page}&per_page={per_page}", per_page=50)
        self.assertEqual(len(res), 2)
        mock_req.assert_called_once_with(
            "https://api.test?page=1&per_page=50", token=None
        )

    @patch("sync_labels.request")
    def test_paginate_multiple_pages(self, mock_req):
        page1 = [{"name": f"item{i}"} for i in range(50)]
        page2 = [{"name": f"item{i}"} for i in range(50, 70)]
        mock_req.side_effect = [page1, page2]

        res = sl.paginate("https://api.test?page={page}&per_page={per_page}", per_page=50)
        self.assertEqual(len(res), 70)
        self.assertEqual(mock_req.call_count, 2)

    @patch("sync_labels.request")
    def test_paginate_exact_page_boundary(self, mock_req):
        page1 = [{"name": f"item{i}"} for i in range(50)]
        page2 = []
        mock_req.side_effect = [page1, page2]

        res = sl.paginate("https://api.test?page={page}&per_page={per_page}", per_page=50)
        self.assertEqual(len(res), 50)
        self.assertEqual(mock_req.call_count, 2)

    @patch("sync_labels.request")
    def test_paginate_empty(self, mock_req):
        mock_req.return_value = []
        res = sl.paginate("https://api.test?page={page}&per_page={per_page}", per_page=50)
        self.assertEqual(res, [])
        mock_req.assert_called_once()


class TestLabelOperations(unittest.TestCase):
    """Edge cases for label CRUD operations and usage querying."""

    @patch("sync_labels.request")
    def test_usage_count_zero(self, mock_req):
        mock_req.return_value = []
        count = sl.usage_count("Unused Label", "token")
        self.assertEqual(count, 0)
        mock_req.assert_called_once_with(
            f"{sl.GITHUB_API}/repos/{sl.GITHUB_REPO}/issues"
            f"?labels=Unused%20Label&state=all&per_page=100",
            token="token",
        )

    @patch("sync_labels.request")
    def test_usage_count_active(self, mock_req):
        mock_req.return_value = [{"number": 1}, {"number": 2}]
        count = sl.usage_count("Priority/High", "token")
        self.assertEqual(count, 2)
        mock_req.assert_called_once_with(
            f"{sl.GITHUB_API}/repos/{sl.GITHUB_REPO}/issues"
            f"?labels=Priority%2FHigh&state=all&per_page=100",
            token="token",
        )

    @patch("sync_labels.request")
    def test_create_label(self, mock_req):
        label = {"name": "Test/Label", "color": "123456", "description": "Desc"}
        sl.create_label(label, "tok")
        mock_req.assert_called_once_with(
            f"{sl.GITHUB_API}/repos/{sl.GITHUB_REPO}/labels",
            token="tok",
            method="POST",
            payload=label,
        )

    @patch("sync_labels.request")
    def test_update_label(self, mock_req):
        label = {"name": "Area/Prompt & Theme", "color": "abcdef", "description": "New"}
        sl.update_label(label, "tok")
        mock_req.assert_called_once_with(
            f"{sl.GITHUB_API}/repos/{sl.GITHUB_REPO}/labels/Area%2FPrompt%20%26%20Theme",
            token="tok",
            method="PATCH",
            payload={
                "new_name": "Area/Prompt & Theme",
                "color": "abcdef",
                "description": "New",
            },
        )

    @patch("sync_labels.request")
    def test_delete_label(self, mock_req):
        sl.delete_label("Reviewed/Won't Fix", "tok")
        mock_req.assert_called_once_with(
            f"{sl.GITHUB_API}/repos/{sl.GITHUB_REPO}/labels/Reviewed%2FWon%27t%20Fix",
            token="tok",
            method="DELETE",
        )


class TestRunAndMainWorkflow(unittest.TestCase):
    """End-to-end execution testing dry-run, live execution, and error handling."""

    def setUp(self):
        self.env_patcher = patch.dict(os.environ, {}, clear=True)
        self.env_patcher.start()

    def tearDown(self):
        self.env_patcher.stop()

    def test_run_missing_token_not_dry_run_raises(self):
        with self.assertRaises(sl.SyncError) as ctx:
            sl.run(dry_run=False)
        self.assertIn("GH_MIRROR_TOKEN is not set", str(ctx.exception))

    @patch("sync_labels.fetch_gitea_labels")
    def test_run_gitea_empty_raises(self, mock_gitea):
        os.environ[sl.TOKEN_ENV] = "dummy_token"
        mock_gitea.return_value = []
        with self.assertRaises(sl.SyncError) as ctx:
            sl.run(dry_run=False)
        self.assertIn("Gitea returned no labels", str(ctx.exception))

    @patch("sys.stdout", new_callable=io.StringIO)
    @patch("sync_labels.delete_label")
    @patch("sync_labels.update_label")
    @patch("sync_labels.create_label")
    @patch("sync_labels.usage_count")
    @patch("sync_labels.fetch_github_labels")
    @patch("sync_labels.fetch_gitea_labels")
    def test_run_dry_run_makes_no_mutating_calls(
        self, mock_gitea, mock_gh, mock_usage, mock_create, mock_update, mock_delete, mock_stdout
    ):
        mock_gitea.return_value = [
            {"name": "Keep", "color": "111111", "description": "Same"},
            {"name": "New", "color": "222222", "description": "Created"},
            {"name": "Change", "color": "333333", "description": "Updated"},
        ]
        mock_gh.return_value = [
            {"name": "Keep", "color": "111111", "description": "Same"},
            {"name": "Change", "color": "000000", "description": "Old"},
            {"name": "ExtraUnused", "color": "444444", "description": "Deleted"},
            {"name": "ExtraUsed", "color": "555555", "description": "Kept"},
        ]
        mock_usage.side_effect = lambda name, token: 1 if name == "ExtraUsed" else 0

        # In dry run, token is not strictly required
        status = sl.run(dry_run=True)
        self.assertEqual(status, 0)
        mock_create.assert_not_called()
        mock_update.assert_not_called()
        mock_delete.assert_not_called()

    @patch("sys.stdout", new_callable=io.StringIO)
    @patch("sync_labels.delete_label")
    @patch("sync_labels.update_label")
    @patch("sync_labels.create_label")
    @patch("sync_labels.usage_count")
    @patch("sync_labels.fetch_github_labels")
    @patch("sync_labels.fetch_gitea_labels")
    def test_run_live_executes_plan(
        self, mock_gitea, mock_gh, mock_usage, mock_create, mock_update, mock_delete, mock_stdout
    ):
        os.environ[sl.TOKEN_ENV] = "my_token"
        mock_gitea.return_value = [
            {"name": "Keep", "color": "111111", "description": "Same"},
            {"name": "New", "color": "222222", "description": "Created"},
            {"name": "Change", "color": "333333", "description": "Updated"},
        ]
        mock_gh.return_value = [
            {"name": "Keep", "color": "111111", "description": "Same"},
            {"name": "Change", "color": "000000", "description": "Old"},
            {"name": "ExtraUnused", "color": "444444", "description": "Deleted"},
            {"name": "ExtraUsed", "color": "555555", "description": "Kept"},
        ]
        mock_usage.side_effect = lambda name, token: 1 if name == "ExtraUsed" else 0

        status = sl.run(dry_run=False)
        self.assertEqual(status, 0)
        mock_create.assert_called_once_with(
            {"name": "New", "color": "222222", "description": "Created"}, "my_token"
        )
        mock_update.assert_called_once()
        mock_delete.assert_called_once_with("ExtraUnused", "my_token")

    @patch("sys.stdout", new_callable=io.StringIO)
    def test_main_self_test(self, mock_stdout):
        self.assertEqual(sl.main(["--self-test"]), 0)

    @patch("sync_labels.run")
    def test_main_sync_error_exit_code(self, mock_run):
        mock_run.side_effect = sl.SyncError("Boom")
        with patch("sys.stderr", new=io.StringIO()) as fake_err:
            rc = sl.main(["--dry-run"])
            self.assertEqual(rc, 1)
            self.assertIn("error: Boom", fake_err.getvalue())


if __name__ == "__main__":
    unittest.main()
