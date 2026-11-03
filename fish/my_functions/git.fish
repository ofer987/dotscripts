# Project root of git project
function project
  git rev-parse --show-toplevel 2> /dev/null
end
# Change directory into Project root
function root
  cd (project)
end

# Configure custom git commands to be completed using Fish's tab completion
for file in (find ~/.yadr/**/git-* -type f)
  if test -x $file
    set command_name (string replace -a -r '^.*git-' '' $file)

    complete --no-files git -a "__fish_git_complete_custom_command $command_name"
  end
end
