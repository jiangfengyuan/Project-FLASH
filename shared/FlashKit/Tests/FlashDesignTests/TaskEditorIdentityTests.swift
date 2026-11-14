import Testing
import Foundation
import FlashCore
@testable import FlashDesign

@Suite @MainActor struct TaskEditorIdentityTests {
    @Test func retryAfterReminderFailureUpdatesTheSameNewTask() throws {
        let repository = FlashRepository(container:FlashDatabase.makeContainer(inMemory:true))
        let editor = TaskEditorView(selectedDate:Date(),task:nil,
            ideaDraft:IdeaTaskDraft(sourceLogId:UUID().uuidString,title:"Synthetic task"),onSave:{ _ in })
        let first = editor.makeTask()
        try repository.saveTask(first)
        // Persistence has succeeded; the reminder step can independently fail.
        // The same editor must not allocate another row when its user retries.
        let retry = editor.makeTask()
        try repository.saveTask(retry)
        #expect(retry.id == first.id)
        #expect(retry.createdAt == first.createdAt)
        #expect(try repository.tasksOnly().count == 1)
    }
    @Test func separateEditorsHaveSeparateIdentities() {
        let first = TaskEditorView(selectedDate:Date(),task:nil,onSave:{ _ in }).makeTask()
        let second = TaskEditorView(selectedDate:Date(),task:nil,onSave:{ _ in }).makeTask()
        #expect(first.id != second.id)
    }
}
