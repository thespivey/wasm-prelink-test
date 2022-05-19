#include <iostream>
#include <cstring>

extern "C" char const* csa_func_1();
extern "C" char const* csa_func_2();
extern "C" char const* common_protobuf_func();
extern "C" char const* only_their_protobuf_func();

void check(char const* actual, char const* expected) {
   if (strcmp(actual, expected)) {
      std::cout << "FAILURE: Expected " << expected << " got " << actual << std::endl;
      std::exit(-1);
   }
}

int main() {
   check(csa_func_1(), "ours");
   check(csa_func_2(), "ours");
   check(common_protobuf_func(), "theirs");
   check(only_their_protobuf_func(), "theirs");

   std::cout << "SUCCESS!" << std::endl;
}