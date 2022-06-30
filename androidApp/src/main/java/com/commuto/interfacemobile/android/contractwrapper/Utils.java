package com.commuto.interfacemobile.android.contractwrapper;

import org.web3j.abi.TypeReference;
import org.web3j.abi.datatypes.*;

import java.lang.reflect.ParameterizedType;

/*
Added to work around Web3j's inability to decode DynamicArrays properly. The code in this class is
taken entirely from Web3j's Utils, and it is a temporary workaround.
 */
public class Utils {
    static String getSimpleTypeName(Class<?> type) {
        String simpleName = type.getSimpleName().toLowerCase();

        if (type.equals(Uint.class)
                || type.equals(Int.class)
                || type.equals(Ufixed.class)
                || type.equals(Fixed.class)) {
            return simpleName + "256";
        } else if (type.equals(Utf8String.class)) {
            return "string";
        } else if (type.equals(DynamicBytes.class)) {
            return "bytes";
        } else if (StructType.class.isAssignableFrom(type)) {
            return type.getName();
        } else {
            return simpleName;
        }
    }

    @SuppressWarnings("unchecked")
    static <T extends Type> Class<T> getParameterizedTypeFromArray(TypeReference typeReference)
            throws ClassNotFoundException {

        java.lang.reflect.Type type = typeReference.getType();
        java.lang.reflect.Type[] typeArguments =
                ((ParameterizedType) type).getActualTypeArguments();

        String parameterizedTypeName = typeArguments[0].getTypeName();
        return (Class<T>) Class.forName(parameterizedTypeName);
    }

}
