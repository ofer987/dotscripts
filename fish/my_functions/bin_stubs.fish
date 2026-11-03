function try_binstub
  set -x directory $argv[1]
  set -x command $argv[2]
  set -x arguments ""
  set -x arg_count (count $argv)
  set -x current_dir (pwd)
  if test $arg_count -gt 2
    set -x arguments $argv[3..-1]
  end

  cd $directory

  if not test -x "$command"
    cd $current_dir
    false
  else
    eval "$command $arguments"

    cd $current_dir
    true
  end
end

function run_binstub
  set -x command $argv[1]
  set -x arguments ""
  set -x arg_count (count $argv)
  if test $arg_count -gt 1
    set -x arguments $argv[2..-1]
  end

  set -x PROJECT (git rev-parse --show-toplevel 2> /dev/null)
  set -q $PROJECT
  if [ $status -eq 1 ]
    if try_binstub "$PROJECT" "bin/$command" $arguments
      return 0
    end
  end
  if try_binstub '.' "bin/$command" $arguments
    return 0
  end
  if try_binstub '.' (rbenv which $command) $arguments
    return 0
  end

  return 1
end

function console
  run_binstub rails console $argv
end

function rails
  run_binstub rails $argv
end

function rake
  run_binstub rake $argv
end

function rspec
  run_binstub rspec $argv
end

function guard
  run_binstub guard
end

function stop_spring
  run_binstub spring stop
end
