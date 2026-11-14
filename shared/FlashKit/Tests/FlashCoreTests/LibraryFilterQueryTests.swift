import Testing
@testable import FlashCore

@Suite struct LibraryFilterQueryTests {
    @Test func queryMatchesTagOrTitleAndKeepsOtherConstraints() {
        let reading = PersonalTag(name:"Reading"), travel = PersonalTag(name:"旅行")
        var library = PersonalLibrary(); library.tags = [reading,travel]
        let records = [
            LibraryRecord(key:"log:a",kind:.log,title:"An example",day:"2026-11-01",createdAt:"1",color:"daily",favorite:true,completed:false),
            LibraryRecord(key:"task:b",kind:.task,title:"READING title",day:"2026-11-02",createdAt:"2",color:"memo",favorite:false,completed:true),
            LibraryRecord(key:"log:c",kind:.log,title:"Café",day:"2026-11-03",createdAt:"3",color:"daily",favorite:false,completed:false),
            LibraryRecord(key:"task:d",kind:.task,title:"Open task",day:"2026-11-04",createdAt:"4",color:"memo",favorite:true,completed:false)]
        library.links = ["log:a":[reading.id],"task:b":[travel.id],"task:d":[reading.id,travel.id]]
        var filter = LibraryFilter(); filter.query = "reading"
        #expect(filter.apply(records,library:library).map(\.key) == ["task:d","task:b","log:a"])
        filter.kinds = [.task]; filter.taskStatus = "open"
        #expect(filter.apply(records,library:library).map(\.key) == ["task:d"])
        filter.kinds = []; filter.taskStatus = "all"; filter.tagIDs = [reading.id,travel.id]; filter.matchAll = true
        #expect(filter.apply(records,library:library).map(\.key) == ["task:d"])
        filter.matchAll = false
        #expect(filter.apply(records,library:library).map(\.key) == ["task:d","task:b","log:a"])
        filter.tagIDs = []; filter.query = "Cafe\u{301}"
        #expect(filter.apply(records,library:library).map(\.key) == ["log:c"])
        filter.query = "旅行"; filter.favoritesOnly = true
        #expect(filter.apply(records,library:library).map(\.key) == ["task:d"])
        filter.query = "missing"
        #expect(filter.apply(records,library:library).isEmpty)
        #expect(filter.apply([],library:library).isEmpty)
    }
}
