import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Blocos de 5 horas")
struct FiveHourBlockTests {

    @Test("Início do bloco é arredondado para baixo na hora cheia (UTC)")
    func startRoundsDownToFullHour() {
        let event = makeEvent(timestamp: utcDate(2026, 9, 17, 14, 37, 22))
        let blocks = FiveHourBlockBuilder.buildBlocks(from: [event])

        #expect(blocks.count == 1)
        #expect(blocks[0].start == utcDate(2026, 9, 17, 14, 0, 0))
        #expect(blocks[0].end == utcDate(2026, 9, 17, 19, 0, 0))
    }

    @Test("Eventos dentro de 5h do início e do evento anterior ficam no mesmo bloco")
    func eventsWithinFiveHoursStayInSameBlock() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 5), messageId: "m1", requestId: "r1"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 12, 0), messageId: "m2", requestId: "r2"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 14, 30), messageId: "m3", requestId: "r3")
        ]
        let blocks = FiveHourBlockBuilder.buildBlocks(from: events)

        #expect(blocks.count == 1)
        #expect(blocks[0].events.count == 3)
        #expect(blocks[0].start == utcDate(2026, 9, 17, 10, 0))
    }

    @Test("Gap maior que 5h desde o evento anterior abre um novo bloco")
    func gapLargerThanFiveHoursOpensNewBlock() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 8, 0), messageId: "m1", requestId: "r1"),
            // 6 horas depois: mesmo estando perto do início nominal, o gap sozinho já força novo bloco.
            makeEvent(timestamp: utcDate(2026, 9, 17, 14, 0), messageId: "m2", requestId: "r2")
        ]
        let blocks = FiveHourBlockBuilder.buildBlocks(from: events)

        #expect(blocks.count == 2)
        #expect(blocks[0].events.count == 1)
        #expect(blocks[1].events.count == 1)
        #expect(blocks[0].start == utcDate(2026, 9, 17, 8, 0))
        #expect(blocks[1].start == utcDate(2026, 9, 17, 14, 0))
    }

    @Test("Evento a mais de 5h do início do bloco abre novo bloco mesmo sem gap desde o anterior")
    func eventBeyondBlockStartOpensNewBlockEvenWithSmallGap() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 0), messageId: "m1", requestId: "r1"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 12, 0), messageId: "m2", requestId: "r2"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 14, 0), messageId: "m3", requestId: "r3"),
            // 5h40 desde o início do bloco (10:00), mas só 1h40 desde o evento anterior (14:00).
            makeEvent(timestamp: utcDate(2026, 9, 17, 15, 40), messageId: "m4", requestId: "r4")
        ]
        let blocks = FiveHourBlockBuilder.buildBlocks(from: events)

        #expect(blocks.count == 2)
        #expect(blocks[0].events.count == 3)
        #expect(blocks[1].events.count == 1)
        #expect(blocks[1].start == utcDate(2026, 9, 17, 15, 0))
    }

    @Test("Bloco ativo é aquele cujo fim ainda está no futuro")
    func activeBlockHasFutureEnd() {
        let event = makeEvent(timestamp: utcDate(2026, 9, 17, 14, 0))
        let blocks = FiveHourBlockBuilder.buildBlocks(from: [event])

        #expect(blocks[0].isActive(now: utcDate(2026, 9, 17, 16, 0)) == true)
        #expect(blocks[0].isActive(now: utcDate(2026, 9, 17, 19, 30)) == false)
    }

    @Test("Eventos fora de ordem são ordenados antes de agrupar")
    func eventsAreSortedBeforeGrouping() {
        let events = [
            makeEvent(timestamp: utcDate(2026, 9, 17, 12, 0), messageId: "m2", requestId: "r2"),
            makeEvent(timestamp: utcDate(2026, 9, 17, 10, 0), messageId: "m1", requestId: "r1")
        ]
        let blocks = FiveHourBlockBuilder.buildBlocks(from: events)

        #expect(blocks.count == 1)
        #expect(blocks[0].start == utcDate(2026, 9, 17, 10, 0))
    }
}
