#include "key.hpp"
#include "bls.hpp"
#include <iostream>
#include <vector>
using namespace std;
using namespace bls;

//int GROUP_ORDER = 0x73EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001;

long factorial(int n) {
    vector<uint8_t> seed = {0,  50, 6,  244, 24,  199, 1,  25,  52,  88,  192,
        19, 18, 12, 89,  6,   220, 18, 102, 58,  209, 82,
        12, 62, 89, 110, 182, 9,   44, 20,  254, 22};
    
    PrivateKey sk = AugSchemeMPL().KeyGen(seed);
    G1Element pk = sk.GetG1Element();
    vector<uint8_t> message = {1, 2, 3, 4, 5};  // Message is passed in as a byte vector
    G2Element signature = AugSchemeMPL().Sign(sk, message);
    bool ok = AugSchemeMPL().Verify(pk, message, signature);
   
    
    if (n == 0 || n == 1) return 1;
    return n * factorial(n-1);
}

PrivateKey get_sk(const char* key) {
    vector<uint8_t> key_vector = Util::HexToBytes(key);
    PrivateKey sk = PrivateKey::FromByteVector(key_vector, false);
    return sk;
}

G2Element get_signature(const char* sig) {
    vector<uint8_t> byte_vector = Util::HexToBytes(sig);
    G2Element signature = G2Element::FromByteVector(byte_vector, false);
    return signature;
}

const char* key_to_str(PrivateKey key) {
    vector<uint8_t> serialized = key.Serialize();
    string serialized_sk = Util::HexStr(serialized);
    const char* result = serialized_sk.c_str();
    return strdup(result);
}

const char* signature_to_str(G2Element signature) {
    vector<uint8_t> serialized = signature.Serialize();
    string serialized_sk = Util::HexStr(serialized);
    const char* result = serialized_sk.c_str();
    return strdup(result);
}

const char* generate_key(const char* seed_str) {
    vector<uint8_t> seed = Util::HexToBytes(seed_str);
    PrivateKey sk = AugSchemeMPL().KeyGen(seed);
    vector<uint8_t> serialized = sk.Serialize();
    string serialized_sk = Util::HexStr(serialized);
    const char* result = serialized_sk.c_str();
    return strdup(result);
}

const char* get_g1(const char* key) {
    vector<uint8_t> key_vector = Util::HexToBytes(key);
    PrivateKey sk = PrivateKey::FromByteVector(key_vector, false);
    G1Element g1 = sk.GetG1Element();
    vector<uint8_t> serialized = g1.Serialize();
    string serialized_sk = Util::HexStr(serialized);
    const char* result = serialized_sk.c_str();
    return strdup(result);
}

const char* derive_child_key_hardened(const char* key, int index) {
    PrivateKey sk = get_sk(key);
    PrivateKey new_sk = AugSchemeMPL().DeriveChildSk(sk, index);
    return key_to_str(new_sk);
}

const char* derive_child_key_unhardened(const char* key, int index) {
    PrivateKey sk = get_sk(key);
    PrivateKey new_sk = AugSchemeMPL().DeriveChildSkUnhardened(sk, index);
    return key_to_str(new_sk);
}

const char* add_g1(const char* key, const char* key1) {
    vector<uint8_t> key_vector = Util::HexToBytes(key);
    G1Element key_g1 = G1Element::FromByteVector(key_vector, false);
    vector<uint8_t> key1_vector = Util::HexToBytes(key1);
    G1Element key1_g1 = G1Element::FromByteVector(key1_vector, false);
    G1Element sum = key_g1 + key1_g1;
    vector<uint8_t> serialized = sum.Serialize();
    string serialized_sk = Util::HexStr(serialized);
    const char* result = serialized_sk.c_str();
    return strdup(result);
}

const char* swift_sign(const char* key_str, const char* message_str) {
    PrivateKey sk = get_sk(key_str);
    vector<uint8_t> message = Util::HexToBytes(message_str);
    G2Element signature = AugSchemeMPL().Sign(sk, message);
    return signature_to_str(signature);
}

const char* swift_aggregate(const char* sig1, const char* sig2) {
    G2Element signature1 = get_signature(sig1);
    G2Element signature2 = get_signature(sig2);
    G2Element result = signature1 + signature2;
    return signature_to_str(result);
}
