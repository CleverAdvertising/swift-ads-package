import Foundation
import Combine

@available(iOS 13.0, *)
class CounterStorage {
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    func storeCounterData(scriptId: Int) -> AnyPublisher<Void, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {
                let value = String(Date().timeIntervalSince1970)
                self.userDefaults.set(value, forKey: "clever-counter-\(scriptId)")
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func clearCounterData(scriptId: String) -> AnyPublisher<Void, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {
                self.userDefaults.removeObject(forKey: "clever-counter-\(scriptId)")
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func getFromStorage(key: String) -> String? {
        return userDefaults.string(forKey: key)
    }

    func saveToStorage(key: String, value: String) -> AnyPublisher<Void, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {
                self.userDefaults.set(value, forKey: key)
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func deleteFromStorage(key: String) -> AnyPublisher<Void, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {
                self.userDefaults.removeObject(forKey: key)
                promise(.success(()))
            }
        }.eraseToAnyPublisher()
    }

    func getCounterData(scriptId: String) -> AnyPublisher<Bool?, Never> {
           return Future { promise in
               let configuredExpirationPublisher = self.getConfiguredExpiration(scriptId: scriptId)
               configuredExpirationPublisher
                   .sink(receiveCompletion: { _ in }) { expiration in
                       guard let expiration = expiration else {
                           promise(.success(false))
                           return
                       }
                       guard let value = self.userDefaults.string(forKey: "clever-counter-\(scriptId)"),
                             let valueNumber = Double(value) else {
                           promise(.success(false))
                           return
                       }

                       let dateValue = Date(timeIntervalSince1970: valueNumber)
                       let dateExpirationValue = self.addHours(date: dateValue, hours: expiration).timeIntervalSince1970
                       let now = Date().timeIntervalSince1970

                       promise(.success(now < dateExpirationValue))
                   }
                   .store(in: &self.cancellables)
           }
           .eraseToAnyPublisher()
       }

    private func addHours(date: Date, hours: Double) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return calendar.date(byAdding: .minute, value: Int(hours * 60), to: date)!
    }

     private func getConfiguredExpiration(scriptId: String) -> AnyPublisher<Double?, Never> {
        return Future { promise in
            DispatchQueue.global(qos: .background).async {
                guard let url = URL(string: "https://scripts-data.cleverwebserver.com/\(scriptId).json") else {
                    promise(.success(nil))
                    return
                }

                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Failed to fetch expiration: \(error)")
                        promise(.success(nil))
                        return
                    }

                    guard var data = data else {
                        promise(.success(nil))
                        return
                    }

                    
                    if let decodedData = Data(base64Encoded: data),
                    let decodedString = String(data: decodedData, encoding: .utf8),
                    decodedString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ||
                    decodedString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
                        data = decodedData
                    }

                    guard
                        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                        let group = json["group"] as? [String: Any],
                        let expireMobile = group["ExpireMobile"] as? Double,
                        expireMobile > 0
                    else {
                        promise(.success(nil))
                        return
                    }

                    promise(.success(expireMobile))
                }.resume()
            }
        }.eraseToAnyPublisher()
    }
}
