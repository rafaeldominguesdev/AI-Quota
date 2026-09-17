import SwiftUI

/// Apelido para `SwiftUI.State`, usado no lugar de `@State` em todas as views deste target.
///
/// POR QUE ISTO EXISTE: no SDK do macOS 26+, `State` passou a ter também uma forma de MACRO
/// (`SwiftUIMacros.StateMacro`), e é ela que o compilador escolhe quando se escreve `@State`.
/// O plugin `libSwiftUIMacros.dylib` só acompanha o Xcode completo — nesta instalação (apenas
/// Command Line Tools) ele não existe, e todo `@State` falha com "plugin for module
/// 'SwiftUIMacros' not found".
///
/// `SwiftUI.State` continua sendo um `@propertyWrapper` normal e funcional; só o atalho `@State`
/// é que virou macro. Referenciar o tipo por outro nome desvia da macro e usa o property wrapper
/// direto, com o mesmo comportamento (incluindo o `$` do projected value / Binding).
///
/// Se um dia este projeto passar a compilar com o Xcode completo, dá para trocar `@ViewState`
/// por `@State` de volta sem nenhuma outra mudança.
typealias ViewState<Value> = SwiftUI.State<Value>
