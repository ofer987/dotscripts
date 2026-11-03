# Get the file/directory's parent
function get_parent
  set path $argv[1]

  set result ""

  set items (string split / $path)
  set count (count $items)

  set count (math $count - 1)

  set i 0
  for item in $items
    if test -n $item && test $i -lt $count
      set result (string join "/" $result $item)
    end

    set i (math $i + 1)
  end

  if test (string sub --length 1 $path) != "/" && test (string sub --length 1 $result) = "/"
    set result (string sub --start=2 $result)
  end

  echo $result
end

# Change into the file's directory
function supercd
  set dir $argv[1];

  # It is an empty string
  if test -z $dir
    return 1;
  end

  while test -n $dir
    if test -d $dir
      cd $dir
      return 0
    else
      set parent (get_parent $dir)
      set dir $parent
    end
  end

  # Failed to retrieve the file's parent directory
  return 1
end

alias "ccd=supercd"
