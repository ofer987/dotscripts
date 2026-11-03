let g:ruby_indent_block_style = 'do'
let g:ruby_indent_assignment_style = 'variable'

autocmd FileType ruby map gj ]m
autocmd FileType ruby map gk [m

function! InsertRubyDebugger(text) abort
  " Current position
  let currentpos = getcurpos()

  " Insert debugging statement
  call append(getcurpos()[1] - 1, repeat(' ', indent('.')) . a:text)

  " Revert to previous position
  call setpos('.', currentpos)
endfunction

function FindProjectDirectory()
  let currentFile = expand('%')
  let fullDirectory = expand('%:p:h')
  let directories = split(fullDirectory, '/')

  let directoryCount = len(directories)
  let i = 0
  while i < directoryCount
    let directorySlice = directories[0:i]
    let directoryPath = join(directorySlice, '/')
    let libDirectoryPath = '/' . join([directoryPath, 'lib'], '/')

    if isdirectory(libDirectoryPath)
      let directories = split(libDirectoryPath, '/')

      return directories[-2]
    endif

    let i += 1
  endwhile

  return ''
endfunction

function ToggleCodeToSpec() abort
  let currentFile = expand('%')

  if currentFile =~ '^lib'
    let projectDirectory = FindProjectDirectory()
    let specFile = substitute(currentFile, '^lib/' . projectDirectory . '/', 'spec/', '')
    let specFile = substitute(specFile, '\.rb$', '_spec.rb', '')

    execute 'edit' specFile
  elseif currentFile =~ '^spec'
    let projectDirectory = FindProjectDirectory()
    let codeFile = substitute(currentFile, '^spec/', 'lib/' . projectDirectory . '/', '')
    let codeFile = substitute(codeFile, '_spec\.rb', '.rb', '')

    execute 'edit' codeFile
  endif
endfunction

autocmd FileType ruby map <leader>dp :call InsertRubyDebugger("require 'pry-byebug'")<CR>
autocmd FileType ruby map <leader>ds :call InsertRubyDebugger("binding.pry")<CR>

autocmd FileType ruby map <leader>dr :call ToggleCodeToSpec()<CR>
