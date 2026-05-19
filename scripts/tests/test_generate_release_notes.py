"""Tests for generate_release_notes.py."""

import sys
import tempfile
from pathlib import Path

# Allow importing generate_release_notes from parent scripts directory
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import generate_release_notes as grn


def test_version_sort_key():
    assert grn.version_sort_key("v1.5.4") == (1, ".", 5, ".", 4)
    assert grn.version_sort_key("v1.5.10") == (1, ".", 5, ".", 10)
    assert grn.version_sort_key("1.2.0") == (1, ".", 2, ".", 0)
    # v1.5.10 should sort after v1.5.4
    assert grn.version_sort_key("v1.5.10") > grn.version_sort_key("v1.5.4")


def test_normalize_version():
    assert grn.normalize_version("v1.5.4") == "1.5.4"
    assert grn.normalize_version("1.2.0") == "1.2.0"


def test_classify_commit_conventional():
    assert grn.classify_commit("feat(ui): add dark mode") == ("功能新增", "add dark mode")
    assert grn.classify_commit("fix(course): crash on empty schedule") == (
        "问题修复",
        "crash on empty schedule",
    )
    assert grn.classify_commit("refactor: clean up utils") == ("改进优化", "clean up utils")
    assert grn.classify_commit("chore(release): prepare v1.5.0") == (
        "发布维护",
        "prepare v1.5.0",
    )
    assert grn.classify_commit("docs: update readme") == ("文档与其他", "update readme")


def test_classify_commit_fallback_chinese():
    assert grn.classify_commit("修复登录页面闪退") == ("问题修复", "修复登录页面闪退")
    assert grn.classify_commit("新增成绩查询功能") == ("功能新增", "新增成绩查询功能")
    assert grn.classify_commit("优化课表加载速度") == ("改进优化", "优化课表加载速度")


def test_load_changelog_section_empty_for_missing_version():
    """When the CHANGELOG doesn't have the version marker, return empty string."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / "CHANGELOG.md").write_text(
            "## v1.5.4\n\nSome content\n\n## v1.5.3\n\nOlder content\n",
            encoding="utf-8",
        )
        result = grn.load_changelog_section(root, "v1.9.9")
        assert result == ""


def test_load_changelog_section_extracts_between_markers():
    """Extract content between two version markers."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / "CHANGELOG.md").write_text(
            "## v1.5.4\n\nRelease notes for 1.5.4\n\n## v1.5.3\n\nOlder notes\n",
            encoding="utf-8",
        )
        result = grn.load_changelog_section(root, "v1.5.4")
        assert "Release notes for 1.5.4" in result
        assert "Older notes" not in result


def test_load_changelog_section_last_version_to_eof():
    """Last version marker extracts to end of file."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / "CHANGELOG.md").write_text(
            "## v1.5.4\n\nLatest\n\n## v1.5.3\n\nOlder\n",
            encoding="utf-8",
        )
        result = grn.load_changelog_section(root, "v1.5.3")
        assert "Older" in result


def test_render_notes_structure():
    commits = [
        ("功能新增", "add dark mode"),
        ("问题修复", "fix crash"),
    ]
    output = grn.render_notes(
        repo="rccuu/superhut",
        current_tag="v1.5.4",
        previous_tag="v1.5.3",
        summary="Test summary",
        commits=commits,
        revspec="v1.5.3...v1.5.4",
    )
    assert "# v1.5.4" in output
    assert "## 维护者摘要" in output
    assert "Test summary" in output
    assert "## 功能新增" in output
    assert "- add dark mode" in output
    assert "## 问题修复" in output
    assert "- fix crash" in output
    assert "## 完整提交列表" in output
    assert "v1.5.3...v1.5.4" in output


def test_render_notes_without_summary():
    commits = [("发布维护", "bump version")]
    output = grn.render_notes(
        repo="rccuu/superhut",
        current_tag="v1.5.4",
        previous_tag="v1.5.3",
        summary="",
        commits=commits,
        revspec="v1.5.3...v1.5.4",
    )
    assert "## 维护者摘要" not in output
    assert "## 发布维护" in output


def test_render_notes_first_release():
    commits = [("功能新增", "initial release")]
    output = grn.render_notes(
        repo="rccuu/superhut",
        current_tag="v1.0.0",
        previous_tag=None,
        summary="First release",
        commits=commits,
        revspec="v1.0.0",
    )
    assert "/releases/tag/v1.0.0" in output
    assert "..." not in output.split("比较范围")[1].split("\n")[0]
