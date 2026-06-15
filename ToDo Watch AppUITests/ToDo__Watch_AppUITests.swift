//
//  ToDo_Watch_AppUITests.swift
//  ToDo Watch AppUITests
//

import XCTest

@MainActor
final class ToDo_Watch_AppUITests: XCTestCase {
   override func setUpWithError() throws {
      continueAfterFailure = false
   }

   func testCaptureWatchHomeView() throws {
      let app = launchScreenshotApp(screen: "home")
      XCTAssertTrue(app.otherElements["watch.home"].waitForExistence(timeout: 8))
      capture("watch-01-HomeView", app: app)
   }

   func testCaptureWatchToDosView() throws {
      let app = launchScreenshotApp(screen: "todos")
      XCTAssertTrue(app.otherElements["watch.todos"].waitForExistence(timeout: 8))
      capture("watch-02-ToDosView", app: app)
   }

   func testCaptureWatchToDoCreateView() throws {
      let app = launchScreenshotApp(screen: "create")
      XCTAssertTrue(app.otherElements["watch.todo.create"].waitForExistence(timeout: 8))
      capture("watch-03-ToDoView-create", app: app)
   }

   func testCaptureWatchToDoDetailView() throws {
      let app = launchScreenshotApp(screen: "detail")
      XCTAssertTrue(app.otherElements["watch.todo.view"].waitForExistence(timeout: 8))
      capture("watch-04-ToDoView-view", app: app)
   }

   func testCaptureWatchStatsView() throws {
      let app = launchScreenshotApp(screen: "stats")
      XCTAssertTrue(app.otherElements["watch.stats"].waitForExistence(timeout: 8))
      capture("watch-05-StatsView", app: app)
   }

   private func launchScreenshotApp(screen: String) -> XCUIApplication {
      let app = XCUIApplication()
      app.launchArguments = [
         "-UITestScreenshotMode",
         "-ScreenshotScreen", screen,
         "-AppleLanguages", "(en)",
         "-AppleLocale", "en_US",
         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryM"
      ]
      app.launch()
      return app
   }

   private func capture(_ name: String, app: XCUIApplication) {
      settle()
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = name
      attachment.lifetime = .keepAlways
      add(attachment)
   }

   private func settle() {
      RunLoop.current.run(until: Date().addingTimeInterval(0.8))
   }
}
