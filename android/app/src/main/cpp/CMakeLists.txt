cmake_minimum_required(VERSION 3.18.1)

project(motamayez_security LANGUAGES C CXX)

add_library(motamayez_security SHARED
  security_native.cpp
)

target_compile_features(motamayez_security PRIVATE cxx_std_17)
target_compile_options(motamayez_security PRIVATE
  -fvisibility=hidden
  -fvisibility-inlines-hidden
  -ffunction-sections
  -fdata-sections
)
target_link_options(motamayez_security PRIVATE
  -Wl,--gc-sections
  -Wl,--strip-all
)

find_library(log-lib log)
target_link_libraries(motamayez_security PRIVATE ${log-lib})
