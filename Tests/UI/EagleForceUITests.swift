import XCTest

final class EagleForceUITests: XCTestCase {
    @MainActor func testVictorySavesRewardsAndUnlocksNextMission() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro", "-autopilot", "-mission", "1"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "boss-health").firstMatch.waitForExistence(timeout: 45))
        capture("06-boss-long-scroll")
        let finale = app.descendants(matching: .any).matching(identifier: "boss-fall-state").firstMatch
        XCTAssertTrue(finale.waitForExistence(timeout: 90))
        XCTAssertFalse(app.staticTexts["result-title"].exists)
        XCTAssertFalse(app.buttons["emp-button"].isEnabled)
        app.buttons["pause-button"].tap()
        XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["result-title"].exists)
        app.buttons["resume-button"].tap()
        capture("11-boss-fall")
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 90))
        XCTAssertEqual(app.staticTexts["result-title"].label, "战区已解放")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "story-outcome").firstMatch.exists)
        XCTAssertTrue(app.buttons["return-base"].waitForExistence(timeout: 5))
        capture("04-victory")
        app.buttons["return-base"].tap()
        XCTAssertTrue(app.buttons["open-hangar"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["selected-mission"].label, "霓虹港湾")
        let launch = app.buttons["launch-mission"]
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: launch)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["mission-2"].isEnabled)
        capture("10-next-mission-selected")
        app.buttons["mission-1"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "objective-clear").firstMatch.label.contains("勋章已获得"))
        XCTAssertTrue(app.staticTexts["已领取"].exists)
        app.buttons["mission-2"].tap()
        launch.tap()
        XCTAssertTrue(app.staticTexts["battle-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["battle-title"].label.contains("霓虹港湾"))
    }

    @MainActor func testGlobalMusicFollowsSettingsAndBackground() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro"]
        app.launch()
        app.buttons["open-profile"].tap()
        let status = app.staticTexts["music-status"]
        XCTAssertEqual(status.label, "背景音乐播放中")
        let toggle = app.switches["audio-toggle"]
        toggle.tap()
        XCTAssertEqual(status.label, "背景音乐已暂停")
        toggle.tap()
        XCTAssertEqual(status.label, "背景音乐播放中")
        app.buttons["return-map"].tap()
        app.buttons["open-hangar"].tap()
        app.buttons["return-map"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.buttons["open-profile"])
        waitForExpectations(timeout: 10)
        app.buttons["open-profile"].tap()
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "背景音乐播放中")
        capture("12-global-music")
    }

    @MainActor func testCampaignMapHangarAndDeployment() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro"]
        app.launch()
        XCTAssertTrue(app.buttons["open-hangar"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["selected-mission"].label, "碧潮群岛")
        XCTAssertFalse(app.buttons["tab-0"].exists)
        XCTAssertTrue(app.buttons["open-profile"].isHittable)
        XCTAssertTrue(app.buttons["launch-mission"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "objective-rescue").firstMatch.label.contains("首次 +100"))
        capture("01-campaign")
        app.buttons["open-hangar"].tap()
        let upgrade = app.buttons["upgrade-weapon"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()
        XCTAssertTrue(app.staticTexts["LV. 1 / 4"].exists)
        capture("02-hangar")
        app.buttons["return-map"].tap()
        app.buttons["mission-1"].tap()
        let launch = app.buttons["launch-mission"]
        XCTAssertTrue(launch.waitForExistence(timeout: 5))
        if !launch.isHittable { app.swipeUp() }
        launch.tap()
        XCTAssertTrue(app.buttons["pause-button"].waitForExistence(timeout: 10))
        capture("00-battle-hud")
        let speed = app.buttons["game-speed"]
        speed.tap()
        XCTAssertTrue(speed.label.contains("1.5"))
        speed.tap()
        XCTAssertEqual(speed.label, "游戏速度 2 倍")
        app.buttons["pause-button"].tap()
        XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
        capture("03-paused")
        app.buttons["resume-button"].tap()
        XCTAssertEqual(speed.label, "游戏速度 2 倍")
        speed.tap()
        XCTAssertEqual(speed.label, "游戏速度 1 倍")
        app.buttons["emp-button"].tap()
        XCTAssertTrue(app.buttons["emp-button"].label.contains("1"))
    }

    @MainActor func testAllFiveBattleScenesAndOrientation() {
        for id in 1...5 {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-shield-demo", "-mission", String(id)]
            app.launch()
            XCTAssertTrue(app.buttons["pause-button"].waitForExistence(timeout: 15))
            let orientation = NSPredicate { _, _ in
                let frame = app.frame
                return frame.height > frame.width
            }
            expectation(for: orientation, evaluatedWith: nil)
            waitForExpectations(timeout: 10)
            // Long press drives the live render loop through the first enemy spawn.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            start.press(forDuration: 12, thenDragTo: end)
            capture("mission-\(id)")
            app.buttons["pause-button"].tap()
            XCTAssertTrue(app.buttons["resume-button"].exists)
            app.buttons["resume-button"].tap()
            app.buttons["emp-button"].tap()
            XCTAssertTrue(app.buttons["emp-button"].label.contains("1"))
            app.terminate()
        }
    }

    @MainActor func testDamageVignetteAndCrashBeforeSettlement() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro", "-damage-demo", "-mission", "1"]
        app.launch()
        let health = app.descendants(matching: .any).matching(identifier: "player-health").firstMatch
        XCTAssertTrue(health.waitForExistence(timeout: 15))
        let critical = NSPredicate(format: "label == %@", "机体耐久 20%")
        expectation(for: critical, evaluatedWith: health)
        waitForExpectations(timeout: 8)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "damage-vignette").firstMatch.label, "红色低血量晕影")
        XCTAssertTrue(app.staticTexts["rescue-hint"].exists)
        capture("07-critical-obstacles-supplies")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)).tap()
        let crash = app.staticTexts["crash-state"]
        XCTAssertTrue(crash.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["emp-button"].isEnabled)
        XCTAssertFalse(app.staticTexts["result-title"].exists)
        app.buttons["pause-button"].tap()
        XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["result-title"].exists)
        app.buttons["resume-button"].tap()
        capture("08-crash-descent")
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["result-title"].label, "整备，再出发")
        XCTAssertTrue(app.buttons["return-base"].waitForExistence(timeout: 5))
        capture("09-crash-result")
    }

    @MainActor func testCharacterDossiersAndRadioLifecycle() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions"]
        app.launch()
        let names = ["韩潮", "维拉", "奥伦", "沈霜", "零点"]
        for id in 1...5 {
            app.buttons["mission-\(id)"].tap()
            app.buttons["open-dossier"].tap()
            XCTAssertTrue(app.staticTexts["story-chapter"].waitForExistence(timeout: 5))
            let enemy = app.staticTexts["enemy-name"]
            if !enemy.isHittable { app.swipeUp() }
            XCTAssertEqual(enemy.label, names[id - 1])
            capture("story-dossier-\(id)")
            app.buttons["close-dossier"].tap()
        }
        app.buttons["mission-1"].tap()
        app.buttons["launch-mission"].tap()
        let caption = app.descendants(matching: .any).matching(identifier: "radio-caption").firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        XCTAssertTrue(caption.label.contains("林汐"))
        capture("story-radio-opening")
        app.buttons["pause-button"].tap()
        XCTAssertEqual(app.staticTexts["voice-status"].label, "语音已停止")
        let voice = app.switches["voice-toggle"]
        voice.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: voice)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(voice.value as? String, "0")
        app.buttons["open-radio-log"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "radio-record-opening").firstMatch.waitForExistence(timeout: 5))
        capture("story-radio-log")
        app.buttons["close-radio-log"].tap()
        app.buttons["resume-button"].tap()
        XCTAssertTrue(caption.exists)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["voice-status"].label, "语音已停止")
        XCTAssertEqual(voice.value as? String, "0")
        capture("story-radio-paused")
    }

    @MainActor func testOpeningStoryPrecedesMapAndDoesNotReplayOnReturn() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["opening-title"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["opening-title"].label, "天穹失联")
        XCTAssertFalse(app.buttons["open-hangar"].exists)
        capture("opening-01")
        app.buttons["opening-next"].tap()
        XCTAssertEqual(app.staticTexts["opening-title"].label, "最后的频道")
        Thread.sleep(forTimeInterval: 0.8) // Let the background crossfade settle before the screenshot.
        capture("opening-02")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["opening-next"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["opening-title"].label, "最后的频道")
        app.buttons["opening-next"].tap()
        XCTAssertEqual(app.staticTexts["opening-title"].label, "破晓，起航")
        Thread.sleep(forTimeInterval: 0.8)
        capture("opening-03")
        // The final page must finish on its own, without tapping into the map.
        XCTAssertTrue(app.buttons["open-hangar"].waitForExistence(timeout: 25))
        app.buttons["open-hangar"].tap()
        app.buttons["return-map"].tap()
        XCTAssertFalse(app.staticTexts["opening-title"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["skip-opening"].waitForExistence(timeout: 15))
        app.buttons["skip-opening"].tap()
        XCTAssertTrue(app.buttons["open-hangar"].waitForExistence(timeout: 5))
    }

    @MainActor func testSupplySilhouettesInHorizontalMission() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-damage-demo", "-mission", "2"]
        app.launch()
        let health = app.descendants(matching: .any).matching(identifier: "player-health").firstMatch
        XCTAssertTrue(health.waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "label == %@", "机体耐久 20%"), evaluatedWith: health)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["rescue-hint"].exists)
        capture("supplies-ground-horizontal")
    }

    @MainActor func testSpecialWeaponsAndThreeEscortsInBothAxes() {
        for mission in [1, 2] {
            for (weapon, title) in [("laser", "贯穿激光"), ("spread", "扇形散弹"), ("lightning", "连锁雷电")] {
                let app = XCUIApplication()
                app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-weapon-demo", weapon, "-mission", String(mission)]
                app.launch()
                let status = app.staticTexts["weapon-status"]
                XCTAssertTrue(status.waitForExistence(timeout: 15))
                expectation(for: NSPredicate(format: "label CONTAINS %@", title), evaluatedWith: status)
                waitForExpectations(timeout: 5)
                XCTAssertEqual(app.staticTexts["escort-count"].label, "护航 3/3")
                XCTAssertGreaterThan(app.frame.height, app.frame.width)
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 1.3)
                capture("weapon-\(weapon)-mission-\(mission)")
                if weapon != "laser" {
                    for frame in 1...3 {
                        Thread.sleep(forTimeInterval: 0.12)
                        capture("weapon-\(weapon)-mission-\(mission)-frame-\(frame)")
                    }
                }
                app.buttons["pause-button"].tap()
                XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
                let pausedWeapon = status.label
                Thread.sleep(forTimeInterval: 0.6)
                XCTAssertEqual(status.label, pausedWeapon)
                app.buttons["resume-button"].tap()
                XCTAssertEqual(app.staticTexts["escort-count"].label, "护航 3/3")
                app.terminate()
            }
        }
    }

    @MainActor func testReducedEffectsStillRendersHorizontalCombat() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions"]
        app.launch()
        app.buttons["open-profile"].tap()
        let toggle = app.switches["降低动态效果"]
        if !toggle.isHittable { app.swipeUp() }
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["return-map"].tap()
        app.buttons["mission-4"].tap()
        app.buttons["launch-mission"].tap()
        let surface = app.descendants(matching: .any).matching(identifier: "battle-surface").firstMatch
        XCTAssertTrue(surface.waitForExistence(timeout: 15))
        XCTAssertEqual(surface.value as? String, "3D projection aligned")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 3)
        capture("reduced-effects-horizontal")
        app.buttons["pause-button"].tap()
        XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
        app.buttons["resume-button"].tap()
        XCTAssertTrue(surface.exists)
    }

    @MainActor func testFiveBossModelsAndProjection() {
        for id in 1...5 {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-boss-demo", "-mission", String(id)]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "boss-health").firstMatch.waitForExistence(timeout: 15))
            let surface = app.descendants(matching: .any).matching(identifier: "battle-surface").firstMatch
            XCTAssertEqual(surface.value as? String, "3D projection aligned")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).press(forDuration: 3)
            capture("3d-boss-\(id)")
            app.terminate()
        }
    }

    @MainActor func testFlightBankAndRinglessSuppliesInBothAxes() {
        for mission in [1, 2] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-flight-test", "-flight-demo", "-weapon-demo", "laser", "-mission", String(mission)]
            app.launch()
            let surface = app.descendants(matching: .any).matching(identifier: "battle-surface").firstMatch
            XCTAssertTrue(surface.waitForExistence(timeout: 15))
            Thread.sleep(forTimeInterval: 1)
            XCTAssertEqual(surface.value as? String, "3D projection aligned")
            let flight = surface.label.split(separator: ",").compactMap { Double($0) }
            XCTAssertEqual(flight.count, 4)
            if flight.count == 4 { XCTAssertGreaterThan(flight[2], 0.5) }
            capture("bank-ringless-mission-\(mission)")
            app.terminate()
        }
    }

    @MainActor func testDraggingBanksAndPauseClearsPendingTravel() {
        for mission in [1, 2] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-skip-intro", "-unlock-missions", "-flight-test", "-mission", String(mission)]
            app.launch()
            let surface = app.descendants(matching: .any).matching(identifier: "battle-surface").firstMatch
            XCTAssertTrue(surface.waitForExistence(timeout: 15))
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.55))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.35))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
            let moved = surface.label.split(separator: ",").compactMap { Double($0) }
            XCTAssertEqual(moved.count, 4)
            if moved.count == 4 { XCTAssertGreaterThan(moved[3], 0.2) }
            app.buttons["pause-button"].tap()
            XCTAssertTrue(app.buttons["resume-button"].waitForExistence(timeout: 5))
            let paused = surface.label.split(separator: ",").compactMap { Double($0) }
            app.buttons["resume-button"].tap()
            Thread.sleep(forTimeInterval: 0.5)
            let resumed = surface.label.split(separator: ",").compactMap { Double($0) }
            XCTAssertEqual(paused.count, 4)
            XCTAssertEqual(resumed.count, 4)
            if paused.count == 4 && resumed.count == 4 {
                XCTAssertEqual(paused[0], resumed[0], accuracy: 0.1)
                XCTAssertEqual(paused[1], resumed[1], accuracy: 0.1)
                XCTAssertEqual(resumed[2], 0, accuracy: 0.05)
            }
            app.terminate()
        }
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
