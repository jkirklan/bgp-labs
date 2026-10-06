import io
import threading
from pathlib import Path
from unittest.mock import patch, MagicMock
from labs.tools.packet_watch.capture import start_capture

_FIXTURES = Path(__file__).parent / "fixtures"


def test_capture_buffers_multiline_json():
    fixture = (_FIXTURES / "tshark_stream_split.txt").read_text()
    received = []
    stop = threading.Event()

    mock_proc = MagicMock()
    mock_proc.stdout = io.StringIO(fixture)
    mock_proc.terminate = lambda: None
    mock_proc.wait = lambda: None

    with patch("subprocess.Popen", return_value=mock_proc):
        stop.set()  # stop after first pass
        start_capture("eth0", "tcp port 179", [], received.append, stop)

    assert len(received) == 2
    assert received[0]["_source"]["layers"]["bgp"]["bgp.type"] == "4"
    assert received[1]["_source"]["layers"]["frame"]["frame.time_epoch"] == "1727285031.456"
