extern "C" char const* common_protobuf_func();
extern "C" char const* only_our_protobuf_func();

__attribute__((visibility("default")))
extern "C" char const* csa_func_1() {
   return common_protobuf_func();
}

__attribute__((visibility("default")))
extern "C" char const* csa_func_2() {
   return only_our_protobuf_func();
}