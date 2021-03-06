package com.reactnativespacex.impl.gen

import com.reactnativespacex.impl.InputValue
import com.reactnativespacex.impl.OutputType
import com.reactnativespacex.impl.Selector

//
// Output Types
//

fun notNull(outputType: OutputType): OutputType {
    return OutputType.NotNull(outputType)
}

fun scalar(name: String): OutputType {
    return OutputType.Scalar(name)
}

fun list(inner: OutputType): OutputType {
    return OutputType.List(inner)
}

fun obj(vararg selector: Selector): OutputType.Object {
    return OutputType.Object(selector.asList())
}

fun obj(selector: List<Selector>): OutputType.Object {
    return OutputType.Object(selector)
}

fun field(name: String, alias: String, type: OutputType): Selector.Field {
    return Selector.Field(name, alias, type, emptyMap())
}

fun field(name: String, alias: String, arguments: Map<String, InputValue>, type: OutputType): Selector.Field {
    return Selector.Field(name, alias, type, arguments)
}

fun fragment(name: String, fragment: OutputType.Object): Selector {
    return Selector.Fragment(name, fragment)
}

fun inline(name: String, fragment: OutputType.Object): Selector {
    return Selector.TypeCondition(name, fragment)
}

//
// Input Types
//

fun refValue(name: String): InputValue.Reference {
    return InputValue.Reference(name)
}

fun intValue(value: Int): InputValue.Int {
    return InputValue.Int(value)
}

fun floatValue(value: Double): InputValue.Float {
    return InputValue.Float(value)
}

fun nullValue(): InputValue.Null {
    return InputValue.Null()
}

fun stringValue(value: String): InputValue.String {
    return InputValue.String(value)
}

fun boolValue(value: Boolean): InputValue.Boolean {
    return InputValue.Boolean(value)
}

fun listValue(vararg inputValue: InputValue): InputValue.List {
    return InputValue.List(inputValue as Array<InputValue>)
}

fun listValue(inputValue: List<InputValue>): InputValue.List {
    return InputValue.List(inputValue.toTypedArray())
}

fun objectValue(vararg args: Pair<String, InputValue>): InputValue.Object {
    return InputValue.Object(args.toMap())
}

fun objectValue(args: Map<String, InputValue>): InputValue.Object {
    return InputValue.Object(args.toMap())
}

fun arguments(vararg args: Pair<String, InputValue>): Map<String, InputValue> {
    return args.toMap()
}

fun fieldValue(name: String, value: InputValue): Pair<String, InputValue> {
    return name to value
}
