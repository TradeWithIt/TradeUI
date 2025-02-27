import Foundation
import GRDB

public final class PersistenceManager: Persistence {
    public static let shared = PersistenceManager()
    private var dbQueue: DatabaseQueue?

    private init() {
        do {
            let fileManager = FileManager.default
            let directory = try fileManager.url(
                for: .downloadsDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
                .appendingPathComponent("Snapshots")
            let dbPath = directory.appendingPathComponent("trades.sqlite").path

            if !fileManager.fileExists(atPath: dbPath) {
                fileManager.createFile(atPath: dbPath, contents: nil, attributes: nil)
            }

            dbQueue = try DatabaseQueue(path: dbPath)
            try setupDatabase()
        } catch {
            print("❌ Database Initialization Error: \(error)")
        }
    }

    private func setupDatabase() throws {
        try dbQueue?.write { db in
            try db.create(table: TradeRecord.databaseTableName, ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("symbol", .text).notNull()
                t.column("entryPrice", .double).notNull()
                t.column("entryTime", .date).notNull()
                t.column("decision", .text).notNull()
                t.column("exitPrice", .double)
                t.column("exitTime", .date)
                t.column("entrySnapshot", .text).notNull()
                t.column("exitSnapshot", .text)
            }
        }
    }

    public func saveTrade(_ trade: TradeRecord) {
        do {
            try dbQueue?.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO trades (id, symbol, entryPrice, entryTime, decision, exitPrice, exitTime, entrySnapshot, exitSnapshot)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        trade.id.uuidString,
                        trade.symbol,
                        trade.entryPrice,
                        trade.entryTime,
                        trade.decision,
                        trade.exitPrice,
                        trade.exitTime,
                        trade.entrySnapshotJSON,
                        trade.exitSnapshotJSON
                    ]
                )
            }
        } catch {
            print("❌ Error saving trade: \(error)")
        }
    }

    public func updateTradeExit(symbol: String, exitPrice: Double, buyingPower: Double, exitSnapshot: [Candle]) {
        do {
            try dbQueue?.write { db in
                if var trade = try TradeRecord
                    .filter(Column("symbol") == symbol && Column("exitPrice") == nil)
                    .fetchOne(db) {
                    
                    trade.exitPrice = exitPrice
                    trade.exitTime = Date()
                    trade.exitSnapshot = exitSnapshot
                    
                    try trade.update(db)
                }
            }
        } catch {
            print("❌ Error updating trade exit: \(error)")
        }
    }

    public func fetchAllTrades() -> [TradeRecord] {
        do {
            return try dbQueue?.read { db in
                try TradeRecord.fetchAll(db)
            } ?? []
        } catch {
            print("❌ Error fetching trades: \(error)")
            return []
        }
    }
}
