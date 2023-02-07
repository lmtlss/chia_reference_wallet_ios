CMAKE_MINIMUM_REQUIRED(VERSION 3.14.0 FATAL_ERROR)
include(FetchContent)
FetchContent_Declare(
  bls
  GIT_REPOSITORY https://github.com/MegaGrindStone/bls-signatures.git
  GIT_TAG origin/flutter-bindings
)
FetchContent_MakeAvailable(bls)
install(FILES $<TARGET_FILE:sodium> DESTINATION lib)
