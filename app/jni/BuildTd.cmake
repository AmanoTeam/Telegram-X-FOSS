cmake_minimum_required(VERSION 3.13)

project(
	tdlib
	VERSION 0.1
	DESCRIPTION "..."
	HOMEPAGE_URL "..."
	LANGUAGES C CXX
)

set(TD_ENABLE_JNI ON)
set(TD_BUILD_JAVA ON)

set(TDLIB_SOURCE_DIRECTORY "${TGX_ROOT_DIR}/td")

set(LIBRESSL_SOURCE_DIRECTORY "${TGX_ROOT_DIR}/libressl")
set(LIBRESSL_AUTOGEN "${LIBRESSL_SOURCE_DIRECTORY}/.autogen")

set(
	TDLIB_TARGETS
	"tdclient"
	"tdjni"
)

set(
	TDLIB_DEPENDENCIES
	"crypto"
	"ssl"
)

set(
	ALL_TARGETS
	${TDLIB_TARGETS}
	${TDLIB_DEPENDENCIES}
)

set(CMAKE_POLICY_DEFAULT_CMP0069 NEW)
set(CMAKE_POLICY_DEFAULT_CMP0048 NEW)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)

set(CMAKE_PLATFORM_NO_VERSIONED_SONAME ON)

file(READ "${TGX_ROOT_DIR}/td/tdactor/CMakeLists.txt" FILE_CONTENTS)
string(REPLACE "(example " "(f76a5d4 " FILE_CONTENTS "${FILE_CONTENTS}")
file(WRITE "${TGX_ROOT_DIR}/td/tdactor/CMakeLists.txt" "${FILE_CONTENTS}")

file(READ "${LIBRESSL_SOURCE_DIRECTORY}/tls/CMakeLists.txt" FILE_CONTENTS)
string(REPLACE "BUILD_SHARED_LIBS" "1" FILE_CONTENTS "${FILE_CONTENTS}")
file(WRITE "${LIBRESSL_SOURCE_DIRECTORY}/tls/CMakeLists.txt" "${FILE_CONTENTS}")

file(READ "${LIBRESSL_SOURCE_DIRECTORY}/ssl/CMakeLists.txt" FILE_CONTENTS)
string(REPLACE "BUILD_SHARED_LIBS" "1" FILE_CONTENTS "${FILE_CONTENTS}")
string(REPLACE "add_library(ssl " "add_library(ssl SHARED " FILE_CONTENTS "${FILE_CONTENTS}")
file(WRITE "${LIBRESSL_SOURCE_DIRECTORY}/ssl/CMakeLists.txt" "${FILE_CONTENTS}")

file(READ "${LIBRESSL_SOURCE_DIRECTORY}/crypto/CMakeLists.txt" FILE_CONTENTS)
string(REPLACE "BUILD_SHARED_LIBS" "1" FILE_CONTENTS "${FILE_CONTENTS}")
string(REPLACE "add_library(crypto " "add_library(crypto SHARED " FILE_CONTENTS "${FILE_CONTENTS}")
file(WRITE "${LIBRESSL_SOURCE_DIRECTORY}/crypto/CMakeLists.txt" "${FILE_CONTENTS}")

file(READ "${LIBRESSL_SOURCE_DIRECTORY}/CMakeLists.txt" FILE_CONTENTS)
string(REPLACE "BUILD_SHARED_LIBS" "1" FILE_CONTENTS "${FILE_CONTENTS}")
string(
	REPLACE
	"project(LibreSSL LANGUAGES C ASM)"
	"project(LibreSSL LANGUAGES C ASM)\n\nset(CMAKE_C_VISIBILITY_PRESET default)\nset(CMAKE_CXX_VISIBILITY_PRESET default)\nset(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)"
	FILE_CONTENTS
	"${FILE_CONTENTS}"
)
file(WRITE "${LIBRESSL_SOURCE_DIRECTORY}/CMakeLists.txt" "${FILE_CONTENTS}")

set(OPENSSL_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/include")

set(OPENSSL_CRYPTO_LIBRARY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${CMAKE_SHARED_LIBRARY_PREFIX}cryptox${CMAKE_SHARED_LIBRARY_SUFFIX}")
set(OPENSSL_SSL_LIBRARY "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${CMAKE_SHARED_LIBRARY_PREFIX}sslx${CMAKE_SHARED_LIBRARY_SUFFIX}")

file(WRITE "${OPENSSL_SSL_LIBRARY}" "")
file(WRITE "${OPENSSL_CRYPTO_LIBRARY}" "")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)

if (NOT EXISTS "${LIBRESSL_AUTOGEN}")
	# Serialize autogen.sh across the per-ABI CMake configure tasks that
	# Gradle runs in parallel. Concurrent runs collide in the shared libressl
	# tree (git index.lock, patches applied twice) and fail.
	file(LOCK "${LIBRESSL_AUTOGEN}.lock")
	
	if (NOT EXISTS "${LIBRESSL_AUTOGEN}")
		message("-- Generating LibreSSL files")
		
		execute_process(
			COMMAND "${LIBRESSL_SOURCE_DIRECTORY}/autogen.sh"
			COMMAND_ERROR_IS_FATAL ANY
			WORKING_DIRECTORY "${LIBRESSL_SOURCE_DIRECTORY}"
		)
		
		file(WRITE "${LIBRESSL_AUTOGEN}" "")
	endif()
	
	file(LOCK "${LIBRESSL_AUTOGEN}.lock" RELEASE)
endif()

add_subdirectory("${LIBRESSL_SOURCE_DIRECTORY}" libressl EXCLUDE_FROM_ALL)

set_target_properties(
	ssl
	PROPERTIES
	OUTPUT_NAME "sslx"
)

set_target_properties(
	crypto
	PROPERTIES
	OUTPUT_NAME "cryptox"
)

set_target_properties(
	crypto_obj ssl_obj compat_obj bs_obj tls_obj tls_compat_obj
	PROPERTIES
	C_VISIBILITY_PRESET default
	CXX_VISIBILITY_PRESET default
	VISIBILITY_INLINES_HIDDEN OFF
)

set(CMAKE_C_VISIBILITY_PRESET default)
set(CMAKE_CXX_VISIBILITY_PRESET default)
set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)

add_subdirectory("${TDLIB_SOURCE_DIRECTORY}" tdlib EXCLUDE_FROM_ALL)

file(REMOVE "${OPENSSL_SSL_LIBRARY}")
file(REMOVE "${OPENSSL_CRYPTO_LIBRARY}")

foreach(dependency ${TDLIB_DEPENDENCIES})
	add_custom_command(
		OUTPUT "${dependency}"
		COMMAND "${CMAKE_COMMAND}" --build ./ --target "${dependency}"
	)
	
	add_custom_target(
		"ensure_${dependency}" ALL DEPENDS "${dependency}"
	)
endforeach()

foreach(target ${TDLIB_TARGETS})
	foreach(dependency ${TDLIB_DEPENDENCIES})
		add_dependencies(
			${target}
			"ensure_${dependency}"
		)
	endforeach()
endforeach()

foreach(target ${ALL_TARGETS})
	install(
		TARGETS ${target}
		RUNTIME DESTINATION bin
		LIBRARY DESTINATION lib
	)
endforeach()

