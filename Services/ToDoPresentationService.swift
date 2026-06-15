import Foundation
import Combine
import SwiftData

@MainActor
final class ToDoPresentationService: ObservableObject {
   struct CompletionEvent: Identifiable {
      let id = UUID()
      let toDoID: PersistentIdentifier
   }

   enum Route: Identifiable {
      case create(presentationID: UUID, preselectedTagID: PersistentIdentifier?)
      case view(ToDo)
      case edit(ToDo)

      var id: String {
         switch self {
         case .create(let presentationID, _):
            return "create-\(presentationID.uuidString)"
         case .view(let toDo):
            return "view-\(String(describing: toDo.id))"
         case .edit(let toDo):
            return "edit-\(String(describing: toDo.id))"
         }
      }
   }

   static let shared = ToDoPresentationService()

   @Published var activeRoute: Route?
   @Published private(set) var completionEvent: CompletionEvent?

   private init() {}

   func create(preselectedTagID: PersistentIdentifier?) {
      AppLog.info("ToDo presentation requested: create")
      activeRoute = .create(
         presentationID: UUID(),
         preselectedTagID: preselectedTagID
      )
   }

   func view(_ toDo: ToDo) {
      AppLog.info("ToDo presentation requested: view")
      activeRoute = .view(toDo)
   }

   func edit(_ toDo: ToDo) {
      AppLog.info("ToDo presentation requested: edit")
      activeRoute = .edit(toDo)
   }

   func finish(savedToDo: ToDo? = nil) {
      AppLog.info("ToDo presentation finished")
      activeRoute = nil

      if let savedToDo {
         completionEvent = CompletionEvent(toDoID: savedToDo.id)
      }
   }

   func dismiss() {
      AppLog.info("ToDo presentation dismissed")
      activeRoute = nil
   }
}
