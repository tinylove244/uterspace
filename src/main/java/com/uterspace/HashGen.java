package com.uterspace;
import com.uterspace.util.PasswordUtil;
public class HashGen {
    public static void main(String[] args) {
        System.out.println("HASH_RESULT=" + PasswordUtil.hashPassword("12345678"));
    }
}
