import XCTest
import AVFoundation
@testable import File_Environment

// MARK: - PlayerController Tests

final class PlayerControllerTests: XCTestCase {

    var controller: PlayerController!

    override func setUp() {
        super.setUp()
        controller = PlayerController()
    }

    // 初期状態
    func testInitialState() {
        XCTAssertNil(controller.player)
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0)
        XCTAssertEqual(controller.duration, 0)
    }

    // play/pause のフラグ更新
    func testPlaySetsIsPlaying() {
        controller.player = AVPlayer()
        controller.play()
        XCTAssertTrue(controller.isPlaying)
    }

    func testPauseClearsIsPlaying() {
        controller.player = AVPlayer()
        controller.play()
        controller.pause()
        XCTAssertFalse(controller.isPlaying)
    }

    func testToggleFlipsState() {
        controller.player = AVPlayer()
        XCTAssertFalse(controller.isPlaying)
        controller.toggle()
        XCTAssertTrue(controller.isPlaying)
        controller.toggle()
        XCTAssertFalse(controller.isPlaying)
    }

    // skip(by:) の境界値クランプ
    func testSkipForwardWithinBounds() {
        setupPlayer(currentTime: 30, duration: 60)
        controller.skip(by: 15)
        XCTAssertEqual(controller.currentTime, 45)
    }

    func testSkipBackwardWithinBounds() {
        setupPlayer(currentTime: 30, duration: 60)
        controller.skip(by: -15)
        XCTAssertEqual(controller.currentTime, 15)
    }

    func testSkipClampedToZero() {
        setupPlayer(currentTime: 10, duration: 60)
        controller.skip(by: -100)
        XCTAssertEqual(controller.currentTime, 0)
    }

    func testSkipClampedToDuration() {
        setupPlayer(currentTime: 50, duration: 60)
        controller.skip(by: 100)
        XCTAssertEqual(controller.currentTime, 60)
    }

    func testSkipDoesNothingWithoutPlayer() {
        controller.currentTime = 30
        controller.duration = 60
        controller.skip(by: 10)
        XCTAssertEqual(controller.currentTime, 30)
    }

    // MARK: - Helpers

    private func setupPlayer(currentTime: Double, duration: Double) {
        controller.player = AVPlayer()
        controller.currentTime = currentTime
        controller.duration = duration
    }
}

// MARK: - HistoryItem Tests

final class HistoryItemTests: XCTestCase {

    func testInvalidBookmarkDataProducesNilURL() {
        let item = HistoryItem(id: "x", key: "x", bookmarkData: Data(), displayName: "Test")
        XCTAssertNil(item.url)
    }

    func testDisplayNameIsStored() {
        let item = HistoryItem(id: "a", key: "a", bookmarkData: Data(), displayName: "My Video")
        XCTAssertEqual(item.displayName, "My Video")
    }

    func testEqualityBasedOnAllStoredProperties() {
        let data = Data([0x01, 0x02, 0x03])
        let item1 = HistoryItem(id: "abc", key: "abc", bookmarkData: data, displayName: "A")
        let item2 = HistoryItem(id: "abc", key: "abc", bookmarkData: data, displayName: "A")
        XCTAssertEqual(item1, item2)
    }

    func testInequalityForDifferentKeys() {
        let item1 = HistoryItem(id: "a", key: "a", bookmarkData: Data([0x01]), displayName: "A")
        let item2 = HistoryItem(id: "b", key: "b", bookmarkData: Data([0x02]), displayName: "B")
        XCTAssertNotEqual(item1, item2)
    }

    func testHashableConsistency() {
        let data = Data([0xFF, 0xAA])
        let item = HistoryItem(id: "z", key: "z", bookmarkData: data, displayName: "Z")
        var set = Set<HistoryItem>()
        set.insert(item)
        set.insert(item)
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - formatTimestamp Tests

final class FormatTimestampTests: XCTestCase {

    func testSeconds() {
        XCTAssertEqual(formatTimestamp(45), "0:45")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(formatTimestamp(125), "2:05")
    }

    func testExactlyOneHour() {
        XCTAssertEqual(formatTimestamp(3600), "1:00:00")
    }

    func testHoursMinutesSeconds() {
        XCTAssertEqual(formatTimestamp(3723), "1:02:03")
    }

    func testZero() {
        XCTAssertEqual(formatTimestamp(0), "0:00")
    }

    func testNinetyMinutes() {
        XCTAssertEqual(formatTimestamp(5400), "1:30:00")
    }

    func testSubSecondTruncatesToInt() {
        XCTAssertEqual(formatTimestamp(59.9), "0:59")
    }
}
