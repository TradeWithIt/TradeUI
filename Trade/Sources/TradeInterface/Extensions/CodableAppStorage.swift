import Foundation
import SwiftUI
import Combine

@propertyWrapper
struct CodableAppStorage<Value: Codable>: DynamicProperty {
    @StateObject private var valuePublisher: ValuePublisher<Value>
    private let key: String
    
    var wrappedValue: Value {
        get { valuePublisher.value }
        nonmutating set { valuePublisher.value = newValue }
    }

    init(wrappedValue defaultValue: Value, _ key: String) {
        self.key = key
        if let data = UserDefaults.standard.data(forKey: key),
           let value = try? JSONDecoder().decode(Value.self, from: data) {
            self._valuePublisher = StateObject(wrappedValue: ValuePublisher(initialValue: value, key: key))
        } else {
            self._valuePublisher = StateObject(wrappedValue: ValuePublisher(initialValue: defaultValue, key: key))
        }
    }

    private class ValuePublisher<T: Codable>: ObservableObject {
        @Published var value: T {
            didSet {
                let data = try? JSONEncoder().encode(value)
                UserDefaults.standard.setValue(data, forKey: key)
            }
        }

        let key: String

        init(initialValue: T, key: String) {
            self.value = initialValue
            self.key = key
        }
    }
}
