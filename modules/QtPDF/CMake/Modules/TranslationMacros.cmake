# Adapted from CMake 2.8 QT4_CREATE_TRANSLATION
# TODO: Find a better name for this

# built-in for CMake >= 3.4
include(CMakeParseArguments)

# target_add_qt_translations(<target> [PRO_FILE <path_to_pro_file> [INCLUDEPATH <inc_path>]] TS_FILES <1.ts> [<2.ts> ...])
# Adds translations. A resource file is created by qt_add_translations and added
# to the specified target (requires CMAKE_AUTORCC to be set)
# If PRO_FILE is specified, create_qt_pro_file is called as well to create a
# .pro file from target's sources that can be used with lupdate to easily update
# the translations
function (target_add_qt_translations _TARGET)
  cmake_parse_arguments("" "" "PRO_FILE;INCLUDEPATH" "TS_FILES;QM_FILES" ${ARGN})
  list(SORT _TS_FILES)
  if (_PRO_FILE)
    get_target_property(_sources ${_TARGET} SOURCES)
    list(SORT _sources)
    create_qt_pro_file("${_PRO_FILE}" INCLUDEPATH "${_INCLUDEPATH}" FILES ${_sources} ${_TS_FILES})
  endif ()

  qt5_add_translation(_generated_qm ${_TS_FILES})

  set(_qm_qrc_path ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}_trans.qrc)
  create_translations_resource_file(${_qm_qrc_path} ${_generated_qm} ${_QM_FILES})

  target_sources(${_TARGET} PRIVATE ${_qm_qrc_path})
  # Explicitly set the generated .qm files as dependencies for the autogen
  # target to ensure they are built before AUTORCC is run
  set_target_properties(${_TARGET} PROPERTIES AUTOGEN_TARGET_DEPENDS "${_generated_qm}")
endfunction()

# create_qt_pro_file(<path_to_pro_file> [INCLUDEPATH <inc_path>] FILES <file1> [<file2> ...])
function(create_qt_pro_file _pro_path)
  cmake_parse_arguments("" "" "INCLUDEPATH" "FILES" ${ARGN})
  set(_my_sources)
  set(_my_headers)
  set(_my_forms)
  set(_my_dirs)
  set(_my_resources)
  set(_my_tsfiles)
  set(_my_rcfile)
  set(_my_icnsfile)
  get_filename_component(_pro_basepath ${_pro_path} PATH)
  # Sort files into different categories
  foreach(_file ${_FILES})
    # TODO: Possibly skip files with GENERATED property
    get_filename_component(_ext ${_file} EXT)
    get_filename_component(_abs_FILE ${_file} ABSOLUTE)
    if(NOT _ext)
      list(APPEND _my_dirs ${_abs_FILE})
    elseif(_ext MATCHES "\\.ts")
      list(APPEND _my_tsfiles ${_abs_FILE})
    elseif(_ext MATCHES "\\.ui")
      list(APPEND _my_forms ${_abs_FILE})
    elseif(_ext MATCHES "\\.qrc")
      list(APPEND _my_resources ${_abs_FILE})
    elseif(_ext MATCHES "\\.(h|hpp|hxx)")
      list(APPEND _my_headers ${_abs_FILE})
    elseif(_ext MATCHES "\\.(c|cpp|cxx|c\\+\\+)")
      list(APPEND _my_sources ${_abs_FILE})
    elseif(_ext MATCHES "\\.rc")
      if(_my_rcfile)
        message(AUTHOR_WARNING "create_qt_pro_file got two rc files: ${_my_rcfile} and ${_abs_FILE}. Ignoring the latter.")
      else()
        set(_my_rcfile "${_abs_FILE}")
      endif()
    elseif(_ext MATCHES "\\.icns")
      if(_my_icnsfile)
        message(AUTHOR_WARNING "create_qt_pro_file got two icns files: ${_my_icnsfile} and ${_abs_FILE}. Ignoring the latter.")
      else()
        set(_my_icnsfile "${_abs_FILE}")
      endif()
    else()
      message(AUTHOR_WARNING "create_qt_pro_file cannot handle file '${_abs_FILE}'.")
    endif()
  endforeach(_file)

  # Construct the .pro file
  set(_pro_content "# WARNING: This file was generated automatically by CMake.\n\n")
  set(_pro_content "${_pro_content}error(\"This file is not intended for building ${PROJECT_NAME}. Please use CMake instead. See README.md for further instructions.\")")

  if (_INCLUDEPATH)
    set(_pro_content "${_pro_content}\n\n# INCLUDEPATH must be set so lupdate finds headers, namespace declarations, etc.\n")
    set(_pro_content "${_pro_content}INCLUDEPATH += ${_INCLUDEPATH}")
  endif ()

  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "SOURCES" ${_my_sources})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "HEADERS" ${_my_headers})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "FORMS" ${_my_forms})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "RESOURCES" ${_my_resources})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "RC_FILE" ${_my_rcfile})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "ICON" ${_my_icnsfile})
  _qt_pro_file_add_sources(_pro_content "${_pro_basepath}" "TRANSLATIONS" ${_my_tsfiles})
  set(_pro_content "${_pro_content}\n")

  # Check if the file to produce already exists and is identical to what we
  # would create. If so, don't touch it to avoid unnecessary rebuilds
  set(_write_file TRUE)
  if (EXISTS "${_pro_path}")
    file(READ ${_pro_path} _old_content)
    if ("${_pro_content}" STREQUAL "${_old_content}")
      set(_write_file FALSE)
    endif ("${_pro_content}" STREQUAL "${_old_content}")
  endif (EXISTS "${_pro_path}")
  if (_write_file)
    file(WRITE ${_pro_path} "${_pro_content}")
  endif (_write_file)
endfunction(create_qt_pro_file)

# create_translations_resource_file(<output_var> <1.qm> [<2.qm> ...])
function(create_translations_resource_file outfile)
  # Construct an appropriate resource file
  set(_qm_qrc "<!DOCTYPE RCC>\n<RCC version=\"1.0\">\n<qresource>\n")
  foreach(_file ${ARGN})
    get_filename_component(_filename "${_file}" NAME)
    set(_qm_qrc "${_qm_qrc}<file alias=\"resfiles/translations/${_filename}\">${_file}</file>\n")
  endforeach(_file)
  set(_qm_qrc "${_qm_qrc}</qresource>\n</RCC>\n")

  # Check if the file to produce already exists and is identical to what we
  # would create. If so, don't touch it to avoid unnecessary rebuilds
  set(_write_file TRUE)
  if (EXISTS "${outfile}")
    file(READ ${outfile} _old_content)
    if ("${_qm_qrc}" STREQUAL "${_old_content}")
      set(_write_file FALSE)
    endif ("${_qm_qrc}" STREQUAL "${_old_content}")
  endif (EXISTS "${outfile}")
  if (${_write_file})
    file(WRITE ${outfile} "${_qm_qrc}")
  endif (${_write_file})
endfunction(create_translations_resource_file)


function (_qt_pro_file_add_sources _output_var _pro_basepath _label)
  if(${ARGC} GREATER 3)
    set(_retval "${${_output_var}}\n\n${_label} =")
    foreach(_file ${ARGN})
      file(RELATIVE_PATH _file ${_pro_basepath} ${_file})
      set(_retval "${_retval} \\\n  \"${_file}\"")
    endforeach()
    set(${_output_var} "${_retval}" PARENT_SCOPE)
  endif()
endfunction()
