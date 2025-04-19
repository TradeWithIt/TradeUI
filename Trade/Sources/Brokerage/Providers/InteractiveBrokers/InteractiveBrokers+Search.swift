import Combine
import Foundation
import IBKit

extension InteractiveBrokers {
    public struct Product: Decodable, Contract {
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
        
        public static func fetchProducts(
            symbol: Symbol,
            productType: [IBSecuritiesType],
            productCountry: [String] = ["US"]
        ) throws -> AnyPublisher<[Product], Swift.Error> {
            let url = URL(string: "https://www.interactivebrokers.com/webrest/search/products-by-filters")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody = Product.Request(
                productCountry: productCountry, 
                productSymbol: symbol,
                productType: productType.map({ $0.rawValue })
            )
            request.httpBody = try JSONEncoder().encode(requestBody)

            return URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: Product.Response.self, decoder: JSONDecoder())
                .map { Array($0.products) }
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
         
         {"pageNumber":1,"pageSize":"100","sortField":"symbol","sortDirection":"asc","productCountry":["AT","BE","CZ","DK","EE","FR","DE","GB","GG","HU","IE","IL","IT","JE","LV","LT","LI","LU","MT","NL","NO","PL","PT","ES","SE","CH","GB"],"productSymbol":"","newProduct":"all","productType":["STK","FUT"],"domain":"jp"}
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
                productType: [String] = ["STK"],
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
}
