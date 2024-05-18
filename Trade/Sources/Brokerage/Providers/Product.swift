import Combine
import Foundation

extension Product {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(symbol)
        hasher.combine(exchangeId)
        hasher.combine(localSymbol)
    }

    public static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.type == rhs.type
        && lhs.symbol == rhs.symbol
        && lhs.exchangeId == rhs.exchangeId
        && lhs.localSymbol == rhs.localSymbol
    }
}

public struct Product: Decodable, Hashable, Identifiable {
    public var id: String {
        "\(type) \(symbol) \(exchangeId) \(localSymbol)"
    }
    
    public var label: String {
        let htmlReplacements: [Character: String] = [
                "<": "&lt;",
                ">": "&gt;",
                "&": "&amp;",
                "\"": "&quot;",
                "'": "&apos;"
            ]
        var decodedString = description
        for (character, entity) in htmlReplacements {
            decodedString = decodedString.replacingOccurrences(of: entity, with: String(character))
        }
        return "\(localSymbol) \(decodedString)"
    }
    
    public let type: String
    public let symbol: String
    public let exchangeId: String
    public let localSymbol: String
    public let description: String
    public let conid: Int?
    public let underConid: Int?
    public let isin: String?
    public let cusip: String?
    public let currency: String
    public let country: String
    public let isPrimeExchId: String?
    public let isNewPdt: String
    public let assocEntityId: String
    
    // MARK: Requests
    
    public static func fetchProducts(symbol: Symbol) throws -> AnyPublisher<Product.Response, Error> {
        let url = URL(string: "https://www.interactivebrokers.com/webrest/search/products-by-filters")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = Product.Request(productSymbol: symbol)
        request.httpBody = try JSONEncoder().encode(requestBody)

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: Product.Response.self, decoder: JSONDecoder())
            .mapError { $0 as! Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: Internal Types
    
    public struct Response: Decodable {
        public let products: Set<Product>
        public let productTypeCount: [TypeCount]
        public let productCount: Int
    }

    public struct TypeCount: Decodable {
        public let productType: String
        public let totalCount: Int
    }
    /**
     {"pageNumber":1,"pageSize":"100","sortField":"symbol","sortDirection":"asc","productCountry":["US"],"productSymbol":"MES","newProduct":"all","productType":["FUT"],"domain":"jp"}
     */
    struct Request: Encodable {
        public var pageNumber: Int
        public var pageSize: String
        public var sortField: String
        public var sortDirection: String
        public var productCountry: [String]
        public var productSymbol: String
        public var newProduct: String
        public var productType: [String]
        public var domain: String
        
        init(
            pageNumber: Int = 1,
            pageSize: String = "100",
            sortField: String = "symbol",
            sortDirection: String = "asc",
            productCountry: [String] = ["US"],
            productSymbol: String,
            newProduct: String = "all",
            productType: [String] = ["FUT"],
            domain: String = "jp"
        ) {
            self.pageNumber = pageNumber
            self.pageSize = pageSize
            self.sortField = sortField
            self.sortDirection = sortDirection
            self.productCountry = productCountry
            self.productSymbol = productSymbol
            self.newProduct = newProduct
            self.productType = productType
            self.domain = domain
        }
    }
}
