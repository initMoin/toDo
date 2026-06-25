import Foundation
import Testing
@testable import ToDo

@Suite("Supabase schema contract")
@MainActor
struct SupabaseSchemaContractTests {
    @Test func todoTaskPayloadUsesDomainTaskColumn() throws {
        let payload = SupabaseSchemaContractProbe.toDoPayload(task: "Write spec")
        let keys = try encodedKeys(for: payload)

        #expect(keys.contains("task"))
        #expect(keys.contains("is_done"))
        #expect(keys.contains("updated_at"))
        #expect(keys.contains("complete_when_all_nanodos_done"))
        #expect(!keys.contains("missive"))
        #expect(!keys.contains("title"))
    }

    @Test func nanoDoTaskPayloadUsesDomainTaskColumn() throws {
        let payload = SupabaseSchemaContractProbe.nanoDoPayload(task: "Draft outline")
        let keys = try encodedKeys(for: payload)

        #expect(keys.contains("task"))
        #expect(keys.contains("updated_at"))
        #expect(!keys.contains("title"))
    }

    @Test func semanticDuplicateCleanupIgnoresCreatedAtOnly() {
        #expect(!SupabaseSchemaContractProbe.exactDuplicateKeysMatchWhenOnlyCreatedAtDiffers())
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysMatchWhenOnlyCreatedAtDiffers())
    }

    @Test func semanticDuplicateCleanupStillProtectsDistinctSchedules() {
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysDifferForDifferentDueDates())
        #expect(SupabaseSchemaContractProbe.semanticDuplicateKeysDifferForDifferentRecurrenceCadence())
    }

    private func encodedKeys<T: Encodable>(for payload: T) throws -> Set<String> {
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }
}
