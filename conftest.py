"""
Root conftest: makes the repo importable as the 'labs' package without
requiring 'pip install -e .' by replicating the PYTHONPATH/symlink setup
that lab setup.sh scripts use at runtime.
"""
import sys
from pathlib import Path

_repo = Path(__file__).parent
_parent = _repo.parent
_labs_link = _parent / "labs"

if not _labs_link.exists():
    _labs_link.symlink_to(_repo)
if str(_parent) not in sys.path:
    sys.path.insert(0, str(_parent))
