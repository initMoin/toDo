//
//  ToDoScreenshotUITests.swift
//  ToDoUITests
//

import XCTest

@MainActor
final class ToDoScreenshotUITests: XCTestCase {
   override func setUpWithError() throws {
      continueAfterFailure = false
   }

	   func testCaptureHomeView() throws {
	      let app = launchScreenshotApp(screen: "home")
	      capture("01-HomeView", app: app)
	   }

	   func testCaptureToDosView() throws {
	      let app = launchScreenshotApp(screen: "todos")
	      capture("02-ToDosView", app: app)
	   }

	   func testCaptureToDoCreateView() throws {
	      let app = launchScreenshotApp(screen: "create")
	      capture("03-ToDoView-create", app: app)
	   }

	   func testCaptureToDoDetailView() throws {
	      let app = launchScreenshotApp(screen: "detail")
	      capture("04-ToDoView-view", app: app)
	   }

	   func testCaptureStatsView() throws {
	      let app = launchScreenshotApp(screen: "stats")
	      capture("05-StatsView", app: app)
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
