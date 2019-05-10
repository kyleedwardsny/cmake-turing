cmake_minimum_required(VERSION 3.14)

# Initialize variables
set(states)

# Read the file
if(NOT EXISTS "${TURING_DESCRIPTOR_FILE}")
  message(FATAL_ERROR "File not found: ${TURING_DESCRIPTOR_FILE}")
endif()
file(STRINGS "${TURING_DESCRIPTOR_FILE}" turing_descriptor_contents)
set(linenum 1)
foreach(line IN LISTS turing_descriptor_contents)
  if(NOT line MATCHES "^([a-zA-Z0-9_-]+) ([B01] (LEFT|RIGHT) [a-zA-Z0-9_-]+) ([B01] (LEFT|RIGHT) [a-zA-Z0-9_-]+) ([B01] (LEFT|RIGHT) [a-zA-Z0-9_-]+)$")
    message(FATAL_ERROR "Syntax error in ${TURING_DESCRIPTOR_FILE} line ${linenum}: \"${line}\"")
  endif()

  set(state_name "${CMAKE_MATCH_1}")

  # This has to be broken up because of limits on parentheses pairs in regular expressions
  set(descriptor_B "${CMAKE_MATCH_2}")
  set(descriptor_0 "${CMAKE_MATCH_4}")
  set(descriptor_1 "${CMAKE_MATCH_6}")

  if(NOT descriptor_B MATCHES "^([B01]) (LEFT|RIGHT) ([a-zA-Z0-9_-]+)$")
    message(FATAL_ERROR "Unexpected error") # This should never happen because the syntax has already been checked
  endif()
  set(write_value_B "${CMAKE_MATCH_1}")
  set(next_direction_B "${CMAKE_MATCH_2}")
  set(next_state_B "${CMAKE_MATCH_3}")

  if(NOT descriptor_0 MATCHES "^([B01]) (LEFT|RIGHT) ([a-zA-Z0-9_-]+)$")
    message(FATAL_ERROR "Unexpected error") # This should never happen because the syntax has already been checked
  endif()
  set(write_value_0 "${CMAKE_MATCH_1}")
  set(next_direction_0 "${CMAKE_MATCH_2}")
  set(next_state_0 "${CMAKE_MATCH_3}")

  if(NOT descriptor_1 MATCHES "^([B01]) (LEFT|RIGHT) ([a-zA-Z0-9_-]+)$")
    message(FATAL_ERROR "Unexpected error") # This should never happen because the syntax has already been checked
  endif()
  set(write_value_1 "${CMAKE_MATCH_1}")
  set(next_direction_1 "${CMAKE_MATCH_2}")
  set(next_state_1 "${CMAKE_MATCH_3}")

  # Check that we don't use the special state names ACCEPT and REJECT
  if (state_name MATCHES "^(ACCEPT|REJECT)$")
    message(FATAL_ERROR "State at line ${linenum} cannot use the special state names ACCEPT or REJECT")
  endif()

  # Check that a state with this name doesn't already exist
  if (state_name IN_LIST states)
    message(FATAL_ERROR "State with name \"${state_name}\" defined at line ${state_${state_name}_linenum} redefined at line ${linenum}")
  endif()

  # Store the state info
  list(APPEND states "${state_name}")
  set(state_${state_name}_linenum "${linenum}")
  set(state_${state_name}_write_value_B "${write_value_B}")
  set(state_${state_name}_next_direction_B "${next_direction_B}")
  set(state_${state_name}_next_state_B "${next_state_B}")
  set(state_${state_name}_write_value_0 "${write_value_0}")
  set(state_${state_name}_next_direction_0 "${next_direction_0}")
  set(state_${state_name}_next_state_0 "${next_state_0}")
  set(state_${state_name}_write_value_1 "${write_value_1}")
  set(state_${state_name}_next_direction_1 "${next_direction_1}")
  set(state_${state_name}_next_state_1 "${next_state_1}")

  # Add 1 to the line number for diagnostics
  math(EXPR linenum "${linenum} + 1")
endforeach()

# Check that there is at least one start state
if(states STREQUAL "")
  message(FATAL_ERROR "No states provided")
endif()

# Check that there are no broken graph connections
foreach(state_name IN LISTS states)
  if (NOT "${state_${state_name}_next_state_B}" IN_LIST states AND NOT "${state_${state_name}_next_state_B}" MATCHES "^(ACCEPT|REJECT)$")
    message(FATAL_ERROR "Invalid next state for ${state_name} on line ${state_${state_name}_linenum}: ${state_${state_name}_next_state_B}")
  endif()
  if (NOT "${state_${state_name}_next_state_0}" IN_LIST states AND NOT "${state_${state_name}_next_state_0}" MATCHES "^(ACCEPT|REJECT)$")
    message(FATAL_ERROR "Invalid next state for ${state_name} on line ${state_${state_name}_linenum}: ${state_${state_name}_next_state_0}")
  endif()
  if (NOT "${state_${state_name}_next_state_1}" IN_LIST states AND NOT "${state_${state_name}_next_state_1}" MATCHES "^(ACCEPT|REJECT)$")
    message(FATAL_ERROR "Invalid next state for ${state_name} on line ${state_${state_name}_linenum}: ${state_${state_name}_next_state_1}")
  endif()
endforeach()

# Read the input file
if(NOT EXISTS "${TURING_INPUT_FILE}")
  message(FATAL_ERROR "File not found: ${TURING_INPUT_FILE}")
endif()
file(READ "${TURING_INPUT_FILE}" turing_input_contents)
if(NOT turing_input_contents MATCHES "^([B01]*)\n?$")
  message(FATAL_ERROR "Invalid input file syntax")
endif()

set(tape_contents "${CMAKE_MATCH_1}")
if(tape_contents STREQUAL "") # Make sure the head is always on a valid tape cell
  set(tape_contents "B")
endif()
set(tape_position 0)
set(start_position 0)
list(GET states 0 current_state)

# Execute the program
while(NOT current_state MATCHES "^(ACCEPT|REJECT)$")
  string(SUBSTRING "${tape_contents}" ${tape_position} 1 tape_cell)
  set(write_value "${state_${current_state}_write_value_${tape_cell}}")
  set(next_direction "${state_${current_state}_next_direction_${tape_cell}}")
  set(next_state "${state_${current_state}_next_state_${tape_cell}}")

  math(EXPR second_half_start "${tape_position} + 1")
  string(SUBSTRING "${tape_contents}" 0 ${tape_position} first_half)
  string(SUBSTRING "${tape_contents}" ${second_half_start} -1 second_half)
  set(tape_contents "${first_half}${write_value}${second_half}")

  if(next_direction STREQUAL "LEFT")
    if(tape_position EQUAL 0)
      math(EXPR start_position "${start_position} + 1")
      set(tape_contents "B${tape_contents}")
    else()
      math(EXPR tape_position "${tape_position} - 1")
    endif()
  else()
    math(EXPR tape_position "${tape_position} + 1")
    string(LENGTH "${tape_contents}" tape_len)
    if(tape_position EQUAL tape_len)
      set(tape_contents "${tape_contents}B")
    endif()
  endif()

  set(current_state ${next_state})
endwhile()

# Print the result
if(current_state STREQUAL "ACCEPT")
  message(STATUS "Input was accepted by the machine")
else()
  message(STATUS "Input was rejected by the machine")
endif()

# Print the tape contents
string(LENGTH "${tape_contents}" tape_len)
math(EXPR last "${tape_len} - 1")
set(print_contents)
foreach(i RANGE ${last})
  if(i EQUAL start_position)
    string(APPEND print_contents "[")
  endif()
  if(i EQUAL tape_position)
    string(APPEND print_contents "(")
  endif()
  string(SUBSTRING "${tape_contents}" ${i} 1 tape_cell)
  string(APPEND print_contents "${tape_cell}")
  if(i EQUAL tape_position)
    string(APPEND print_contents ")")
  endif()
  if(i EQUAL start_position)
    string(APPEND print_contents "]")
  endif()
endforeach()
message(STATUS "Tape contents: ${print_contents}")
message(STATUS "[start position], (end position)")
