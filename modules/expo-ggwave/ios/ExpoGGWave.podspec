require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoGGWave'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = {
    :ios => '15.1',
    :tvos => '15.1'
  }
  s.swift_version  = '5.4'
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Swift and Objective-C++ sources, and ggwave C++ sources
  # Note: ggwave.cpp is included via ggwave-impl.mm wrapper to ensure compilation
  s.source_files = [
    "**/*.{h,m,mm,swift}",
    "../cpp/ggwave/ggwave.h",
    "../cpp/fft.h",
    "../cpp/reed-solomon/**/*.{h,hpp}"
  ]

  # Exclude specific directories
  s.exclude_files = "../cpp/CMakeLists.txt"

  # Header search paths for C++ includes
  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../cpp $(PODS_TARGET_SRCROOT)/../cpp/ggwave $(PODS_TARGET_SRCROOT)/../cpp/reed-solomon',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -DGGWAVE_BUILD_EXAMPLES=OFF'
  }

  # Additional compiler flags
  s.compiler_flags = '-DGGWAVE_BUILD_EXAMPLES=OFF'

  # Link against required frameworks
  s.frameworks = 'AVFoundation'

  # Pod target xcconfig
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
