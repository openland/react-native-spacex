package com.reactnativespacex.impl

import com.reactnativespacex.impl.OperationKind
import com.reactnativespacex.impl.OutputType

data class OperationDefinition(val kind: OperationKind, val selector: OutputType.Object, val name: String, val body: String)

data class FragmentDefinition(val name: String, val selector: OutputType.Object)
