from unittest.mock import patch


def test_create_app_stops_poller_on_exit(tmp_path):
    lab_json = tmp_path / "lab.json"
    lab_json.write_text('{"lab": "test-lab", "routers": [], "networks": []}')

    with patch("atexit.register") as mock_register, \
         patch("labs.tools.topology_watch.app.Poller") as MockPoller:
        mock_poller = MockPoller.return_value
        from labs.tools.topology_watch import app as app_module
        app_module.create_app(str(lab_json))
        mock_register.assert_called_once_with(mock_poller.stop)
