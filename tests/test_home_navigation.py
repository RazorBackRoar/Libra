import os

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication

from Libra.gui.main_window import CARDS, ClickableFrame, MainWindow


def _app() -> QApplication:
    app = QApplication.instance()
    if app is None:
        app = QApplication([])
    return app


def test_every_card_id_routes_to_a_defined_screen():
    _app()
    window = MainWindow()

    expected_tool_ids = {card["id"] for card in CARDS if card["id"] != "organizer"}
    assert expected_tool_ids == set(window.tool_page_indexes.keys())

    for card in CARDS:
        window._go_home()
        window._on_tool_click(card)
        if card["id"] == "organizer":
            assert window.stack.currentIndex() == 1
            assert window.current_mode == "organize"
        else:
            assert window.stack.currentIndex() == window.tool_page_indexes[card["id"]]
            assert window.current_mode == card["id"]


def test_clicking_each_home_card_navigates_away_from_home():
    _app()
    window = MainWindow()
    frames = window.findChildren(ClickableFrame)

    assert len(frames) == len(CARDS)
    for frame in frames:
        window._go_home()
        assert window.stack.currentIndex() == 0
        frame.clicked.emit()
        assert window.stack.currentIndex() != 0


def test_each_tool_screen_has_drop_and_status_options():
    _app()
    window = MainWindow()
    tool_ids = [card["id"] for card in CARDS if card["id"] != "organizer"]

    assert set(tool_ids) == set(window.tool_drop_zones.keys())
    assert set(tool_ids) == set(window.tool_status_labels.keys())
