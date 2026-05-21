import Foundation

struct WidgetDeepLinkRouter {
   static let listURL = URL(string: "todo://todo")

   static func toDoURL(for item: ToDoWidgetItem) -> URL? {
      url(for: item)
   }

   static func url(for item: ToDoWidgetItem) -> URL? {
      var components = URLComponents()
      components.scheme = "todo"
      components.host = "todo"
      components.path = "/\(item.cloudID?.uuidString ?? item.id)"
      var queryItems = [URLQueryItem(name: "localIdentifier", value: item.id)]
      if let cloudID = item.cloudID {
         queryItems.append(URLQueryItem(name: "cloudID", value: cloudID.uuidString))
      }
      components.queryItems = queryItems
      return components.url
   }
}
