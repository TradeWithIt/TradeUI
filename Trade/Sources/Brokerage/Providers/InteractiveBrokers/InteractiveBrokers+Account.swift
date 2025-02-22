import Foundation
import Combine
import IBKit

public extension InteractiveBrokers {
    // MARK: - Start Listening to Account Updates
    func startListening(accountId: String) {
        guard self.accounts[accountId] == nil else { return }
        self.accounts[accountId] = Account(name: accountId)
        print("🚀 Start Listening: \(accountId)")
        do {
            try client.subscribePositions()
            try client.requestOpenOrders()
            try client.subscribeAccountSummary(client.nextRequestID, accountGroup: accountId)
        } catch {
            print("Failed to Listen for Account updates with error: \(error)")
        }
    }

    // MARK: - Update Account Data
    func updateAccountData(event: IBAccountUpdate) {
        guard var account = accounts[event.accountName] else { return }
        account.currency = event.currency
        accounts[event.accountName] = account
    }
    
    func updateAccountData(event: IBAccountSummary) {
        guard var account = accounts[event.accountName] else { return }
        let value = event.value
        
        switch event.key {
        case .accountType:
            print("Account Type: \(value)")
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
            print("⚠️ Unhandled account event: \(event.key)")
        }
        
        account.updatedAt = Date()
        accounts[event.accountName] = account
        print("✅ Account updated: \(account)")
    }

    // MARK: - Update Positions
    func updatePositions(_ position: IBPosition) {
        guard var account = accounts[position.accountName] else { return }
        
        let contract = position.contract
        let quantity = position.position
        let avgCost = position.avgCost
        
        // Compute Market Value (Assumption: Market price is retrieved externally)
        let marketPrice = 0.0
        let marketValue = quantity * marketPrice
        
        // Compute Unrealized PNL
        let unrealizedPNL = (marketPrice - avgCost) * quantity
        
        let newPosition = Position(
            type: position.contract.type,
            symbol: position.contract.symbol,
            exchangeId: position.contract.exchangeId,
            currency: position.contract.currency,
            quantity: quantity,
            marketValue: marketValue,
            averageCost: avgCost,
            realizedPNL: 0.0, // Realized PNL is handled in order executions
            unrealizedPNL: unrealizedPNL
        )
        
        // Update or Add Position
        if let index = account.positions.firstIndex(where: { $0.label == contract.label }) {
            account.positions[index] = newPosition
        } else {
            account.positions.append(newPosition)
        }
        
        accounts[position.accountName] = account
        print("📊 Position updated: \(newPosition)")
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
            break
        }
    }
}
