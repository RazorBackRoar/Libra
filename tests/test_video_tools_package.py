from Libra.video_tools.core.classifier import (
    classify_framerate,
    classify_orientation,
    classify_resolution,
)


def test_video_tools_classifier_categories():
    assert classify_resolution(3840, 2160) == "4K"
    assert classify_resolution(1920, 1080) == "1080p"
    assert classify_resolution(1280, 720) == "720p"
    assert classify_orientation(1080, 1920) == "V"
    assert classify_framerate(59.94) == 60
