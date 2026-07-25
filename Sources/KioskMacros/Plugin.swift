import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct KioskMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    InitMacro.self,
    CopyMacro.self,
    MergeMacro.self,
    DataMacro.self,
    LerpMacro.self,
    StyleMacro.self,
    ErasedMacro.self,
    MapMacro.self,
    JsonMacro.self,
    StringMacro.self,
    SnapMacro.self,
    RouteMacro.self,
    ParamMacro.self,
    QueryMacro.self,
    HeaderMacro.self,
    ContentMacro.self,
    WrapMacro.self,
    UnwrapMacro.self,
    PartMacro.self,
    StatusMacro.self,
    CodecMacro.self,
    RenameMacro.self,
    WireMacro.self,
    FieldMacro.self,
    FormatMacro.self,
    DefaultMacro.self,
    GetMacro.self,
    PostMacro.self,
    PutMacro.self,
    PatchMacro.self,
    DeleteMacro.self,
    KeyMacro.self,
  ]
}
