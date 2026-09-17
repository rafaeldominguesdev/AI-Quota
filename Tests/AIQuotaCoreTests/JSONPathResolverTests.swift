import Testing
import Foundation
@testable import AIQuotaCore

@Suite("Resolvedor de caminho JSON por ponto")
struct JSONPathResolverTests {

    // Anotado explicitamente como [String: Any] em cada nível — é exatamente a forma que
    // JSONSerialization.jsonObject(with:) produz de verdade (o resolvedor não deve depender de
    // nenhum tipo concreto mais específico).
    private let json: [String: Any] = [
        "timestamp": "2026-09-17T16:39:27.573Z",
        "payload": [
            "info": [
                "usage": [
                    "input_tokens": 1234,
                    "output_tokens": 56
                ] as [String: Any]
            ] as [String: Any],
            "model": "glm-5"
        ] as [String: Any]
    ]

    @Test("Resolve caminho aninhado de string")
    func resolvesNestedString() {
        #expect(JSONPathResolver.string(at: "payload.model", in: json) == "glm-5")
    }

    @Test("Resolve caminho aninhado de inteiro")
    func resolvesNestedInt() {
        #expect(JSONPathResolver.int(at: "payload.info.usage.input_tokens", in: json) == 1234)
        #expect(JSONPathResolver.int(at: "payload.info.usage.output_tokens", in: json) == 56)
    }

    @Test("Caminho de um nível só")
    func resolvesTopLevelPath() {
        #expect(JSONPathResolver.string(at: "timestamp", in: json) == "2026-09-17T16:39:27.573Z")
    }

    @Test("Caminho inexistente retorna nil, sem crashar")
    func missingPathReturnsNil() {
        #expect(JSONPathResolver.value(at: "payload.info.usage.does_not_exist", in: json) == nil)
        #expect(JSONPathResolver.int(at: "payload.info.usage.does_not_exist", in: json) == nil)
        #expect(JSONPathResolver.string(at: "nope.nope.nope", in: json) == nil)
    }

    @Test("Caminho vazio retorna nil")
    func emptyPathReturnsNil() {
        #expect(JSONPathResolver.value(at: "", in: json) == nil)
    }

    @Test("Caminho que atravessa um valor que não é objeto retorna nil")
    func pathThroughNonObjectReturnsNil() {
        // "payload.model" é uma string; tentar descer mais um nível não deve crashar.
        #expect(JSONPathResolver.value(at: "payload.model.nested", in: json) == nil)
    }

    @Test("Tipo errado no destino retorna nil (int pedido onde há string)")
    func wrongTypeAtDestinationReturnsNil() {
        #expect(JSONPathResolver.int(at: "payload.model", in: json) == nil)
    }
}
