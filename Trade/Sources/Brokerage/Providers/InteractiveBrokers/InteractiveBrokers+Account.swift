import Foundation
import Combine
import IBKit

public extension InteractiveBrokers {
    // MARK: - Start Listening to Account Updates
    func startListening(accountId: String) {
        if self.accounts[accountId] == nil {
            self.accounts[accountId] = Account(name: accountId)
        }
        print("🚀 Start Listening: \(accountId)")
        do {
            try client.subscribeAccountSummary(client.nextRequestID, accountGroup: accountId)
            try client.subscribeAccountUpdates(accountName: accountId, subscribe: true)
            
            try client.requestOpenOrders()
            try client.requestAllOpenOrders()
            try client.requestExecutions(client.nextRequestID)
            
            try client.subscribePositions()
        } catch {
            print("Failed to Listen for Account updates with error: \(error)")
        }
    }

    // MARK: - Update Account Data
    func updateAccountData(event: IBAccountUpdate) {
        guard var account = accounts[event.accountName] else { return }
        
        let value: String = event.value
        let currency: String = event.currency
        let doubleValue: Double? = Double(value)  // Safely convert value to Double
        
        switch event.key {
        case .AccountCode:
            account.name = value
        case .AvailableFunds:
            account.availableFunds = doubleValue ?? 0.0
        case .BuyingPower:
            account.buyingPower = doubleValue ?? 0.0
        case .ExcessLiquidity:
            account.excessLiquidity = doubleValue ?? 0.0
            
        case .InitMarginReq:
            account.initialMargin = doubleValue ?? 0.0
        case .MaintMarginReq:
            account.maintenanceMargin = doubleValue ?? 0.0
        case .NetLiquidation:
            account.netLiquidation = doubleValue ?? 0.0
        case .TotalCashValue, .TotalCashValueC, .TotalCashValueS:
            if let amount = doubleValue {
                account.cashBook.append(Balance(currency: currency, amount: amount))
            }
            
        default:
            break
        }
        
        account.updatedAt = Date()
        accounts[event.accountName] = account
    }
    
    func updateAccountData(event: IBAccountSummary) {
        guard var account = accounts[event.accountName] else { return }
        let value = event.value
        
        switch event.key {
        case .netLiquidation:
            account.netLiquidation = value
        case .totalCash, .settledCash, .accruedCash:
            account.cashBook.append(Balance(currency: event.userInfo, amount: value))
        case .buyingPower:
            account.buyingPower = value
        case .availableFunds:
            account.availableFunds = value
        case .excessLiquidity:
            account.excessLiquidity = value
        case .initialMargin:
            account.initialMargin = value
        case .maintenanceMargin:
            account.maintenanceMargin = value
        case .leverege:
            account.leverage = value
        default:
            break
        }
        
        account.updatedAt = Date()
        accounts[event.accountName] = account
    }

    // MARK: - Update Positions
    
    // MARK: - Update Portfolio Value
    func updatePortfolio(_ value: IBPortfolioValue) {
        guard let contractID = value.contract.id else { return }
        let accountName = value.accountName

        // Check if the position already exists
        if let index = accounts[accountName]?.positions.firstIndex(where: { $0.contractID == contractID }) {
            if value.position == 0 {
                accounts[accountName]?.positions.remove(at: index)
            } else {
                accounts[accountName]?.positions[index].quantity = value.position
                accounts[accountName]?.positions[index].marketValue = value.marketValue
                accounts[accountName]?.positions[index].averageCost = value.averageCost
                accounts[accountName]?.positions[index].unrealizedPNL = value.unrealizedPNL
                accounts[accountName]?.positions[index].realizedPNL = value.realizedPNL
            }
        } else if value.position != 0 {
            // Create a new position if not present
            let newPosition = Position(
                type: value.contract.securitiesType.rawValue,
                symbol: value.contract.localSymbol ?? value.contract.symbol,
                exchangeId: value.contract.exchange?.rawValue ?? "",
                currency: value.contract.currency,
                contractID: contractID,
                quantity: value.position,
                marketValue: value.marketValue,
                averageCost: value.averageCost,
                realizedPNL: value.realizedPNL,
                unrealizedPNL: value.unrealizedPNL
            )
            accounts[accountName]?.positions.append(newPosition)
        }
    }
    
    func updatePositions(_ positionPNL: IBPositionPNL) {
        guard let accountName = positionPNL.account else {
            print("⚠️ Account not found for position update")
            return
        }
        
        guard let contractID = positionPNL.contractID else {
            print("⚠️ Missing contract ID for position update")
            return
        }

        // Find the existing position
        guard let index = accounts[accountName]?.positions.firstIndex(where: { $0.contractID == contractID }) else {
            print("⚠️ Position not found for contract ID: \(contractID)")
            return
        }

        if positionPNL.position == 0 {
            accounts[accountName]?.positions.remove(at: index)
        } else {
            accounts[accountName]?.positions[index].quantity = positionPNL.position
            accounts[accountName]?.positions[index].marketValue = positionPNL.value
            accounts[accountName]?.positions[index].unrealizedPNL = positionPNL.unrealized
            accounts[accountName]?.positions[index].realizedPNL = positionPNL.realized
        }
        print("💵 PositionP&L updated: \(positionPNL)")
    }

    
    func updatePositions(_ position: IBPosition) {
        if let index = accounts[position.accountName]?.positions.firstIndex(where: { $0.contractID == position.contract.id }) {
            if position.position == 0 {
                accounts[position.accountName]?.positions.remove(at: index)
            } else {
                accounts[position.accountName]?.positions[index].quantity = position.position
                accounts[position.accountName]?.positions[index].averageCost = position.avgCost
            }
        } else {
            let newPosition = Position(
                type: position.contract.type,
                symbol: position.contract.localSymbol ?? position.contract.symbol,
                exchangeId: position.contract.exchangeId,
                currency: position.contract.currency,
                contractID: position.contract.id ?? 0,
                quantity: position.position,
                averageCost: position.avgCost
            )
            accounts[position.accountName]?.positions.append(newPosition)
        }
        
        if let contrectId = position.contract.id {
            do {
                try client.subscribePositionPNL(
                    client.nextRequestID,
                    accountName: position.accountName,
                    contractID: contrectId,
                    modelCode: []
                )
            } catch {
                print("failed to subscribe position pnl", error)
            }
        }
        print("📊 Position updated: \(position)")
    }
    
    func updateAccountOrders(event: OrderEvent) {
        switch event {
        case let event as IBOpenOrder:
            guard let accountId = event.order.account else { return }
            
            if self.accounts[accountId] == nil {
                self.accounts[accountId] = Account(name: accountId)
            }
            
            self.accounts[accountId]?.orders[event.order.orderID] = event.order
            
        case let event as IBOrderExecution:
            let filledQuantity = self.accounts[event.account]?.orders[event.orderID]?.filledCount ?? 0
            self.accounts[event.account]?.orders[event.orderID]?.filledCount = filledQuantity + event.shares
        case let event as IBOrderCompletion:
            guard let accountId = event.order.account else { return }
            self.accounts[accountId]?.orders[event.order.orderID] = nil
        case let event as IBOrderStatus:
            switch event.status {
            case .cancelled:
                guard
                    let account = self.account,
                    let orderID = account.orders.values.first(where: { ($0 as? IBOrder)?.permID == event.permID })?.orderID
                else { return }
                self.accounts[account.name]?.orders[orderID] = nil
            default:
                break
            }
        default:
            print("🙌🏻 Order: ", event.self)
        }
    }
}
