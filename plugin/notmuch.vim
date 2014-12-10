if exists("g:loaded_notmuch")
	finish
endif

if !has("ruby") || version < 700
	finish
endif

let g:loaded_notmuch = "yep"

let g:notmuch_folders_maps = {
	\ '<Enter>':	'folders_show_search()',
	\ 's':		'folders_search_prompt()',
	\ 'A':		'folders_tag_all("-inbox -unread")',
	\ '=':		'folders_refresh()',
	\ 'c':		'compose("")',
	\ }

let g:notmuch_search_maps = {
	\ 'q':		'kill_this_buffer()',
	\ '<Enter>':	'search_show_thread(1)',
	\ '<Space>':	'search_show_thread(2)',
	\ 'A':		'search_tag_all("-inbox -unread")',
	\ 'a':		'search_tag("-inbox -unread")',
	\ 'I':		'search_tag("-unread")',
	\ 't':		'search_tag("")',
	\ 's':		'search_search_prompt()',
	\ '=':		'search_refresh()',
	\ '?':		'search_info()',
	\ 'c':		'compose("")',
	\ }

let g:notmuch_show_maps = {
	\ 'q':		'kill_this_buffer()',
	\ 'a':		'show_tag("-inbox -unread")',
	\ 'I':		'show_tag("-unread")',
	\ 't':		'show_tag("")',
	\ 'o':		'show_open_msg()',
	\ 'e':		'show_extract_msg()',
	\ '<Enter>':	'show_view_magic()',
	\ 'x':		'show_fold_message()',
	\ 's':		'show_save_msg()',
	\ 'p':		'show_save_patches()',
	\ 'r':		'show_reply()',
	\ '?':		'show_info()',
	\ '<S-Tab>':	'show_prev_msg()',
	\ '<Tab>':	'show_next_msg("unread")',
	\ 'c':		'compose("")',
	\ }

let g:notmuch_compose_maps = {
	\ ',s':		'compose_send()',
	\ ',q':		'compose_quit()',
	\ }

let s:notmuch_folders_default = [
	\ [ 'new', 'tag:inbox and tag:unread' ],
	\ [ 'inbox', 'tag:inbox' ],
	\ [ 'unread', 'tag:unread' ],
	\ ]

let s:notmuch_show_headers_default = [
	\ 'Subject',
	\ 'To',
	\ 'Cc',
	\ 'Date',
	\ 'Message-ID',
	\ ]

let s:notmuch_sendmail_method_default = 'sendmail'
let s:notmuch_sendmail_param_default = {
	\ }

let s:notmuch_date_format_default = '%d.%m.%y'
let s:notmuch_datetime_format_default = '%d.%m.%y %H:%M:%S'
let s:notmuch_reader_default = 'mutt -f %s'
let s:notmuch_sendmail_default = 'sendmail'
let s:notmuch_view_attachment_default = 'xdg-open'
let s:notmuch_attachment_tmpdir_default = '~/.notmuch/tmp'
let s:notmuch_save_sent_locally_default = 1
let s:notmuch_save_sent_mailbox_default = 'Sent'
let s:notmuch_folders_count_threads_default = 0
let s:notmuch_compose_start_insert_default = 0
let s:notmuch_show_folded_full_headers_default = 1
let s:notmuch_show_folded_threads_default = 1
let s:notmuch_open_uri_default = 'xdg-open'

function! s:new_file_buffer(type, fname)
	exec printf('edit %s', a:fname)
	execute printf('set filetype=notmuch-%s', a:type)
	execute printf('set syntax=notmuch-%s', a:type)
	ruby $curbuf.init(VIM::evaluate('a:type'))
endfunction

function! s:on_compose_delete()
	if b:compose_done
		return
	endif
	if input('[s]end/[q]uit? ') =~ '^s'
		call s:compose_send()
	endif
endfunction

"" actions

function! s:compose_quit()
	let b:compose_done = 1
	call s:kill_this_buffer()
endfunction

function! s:compose_send()
	let b:compose_done = 1
	let fname = expand('%')
	let lines = getline(7, '$')

	ruby rb_compose_send(VIM::evaluate('lines'), VIM::evaluate('fname'))

	call s:kill_this_buffer()
endfunction

function! s:show_prev_msg()
	ruby rb_show_prev_msg()
endfunction

function! s:show_next_msg(matching_tag)
	ruby rb_show_next_msg(VIM::evaluate('a:matching_tag'))
endfunction

function! s:show_reply()
	ruby rb_show_reply(get_message.mail)
	let b:compose_done = 0
	call s:set_map(g:notmuch_compose_maps)
	autocmd BufDelete <buffer> call s:on_compose_delete()
	if g:notmuch_compose_start_insert
		startinsert!
	end
endfunction

function! s:show_fold_message()
ruby << EOF
	m = get_message()
	rb_show_fold_message(m, NMShow::FOLD_AUTO)
EOF
endfunction

function! s:compose(to_email)
	ruby rb_open_compose(VIM::evaluate('a:to_email'))
	let b:compose_done = 0
	call s:set_map(g:notmuch_compose_maps)
	autocmd BufDelete <buffer> call s:on_compose_delete()
	if g:notmuch_compose_start_insert
		startinsert!
	end
endfunction

function! s:show_info()
	ruby vim_puts get_message.inspect
endfunction

function! s:show_view_magic()
	let line = getline(".")
	let pos = getpos(".")
	let lineno = pos[1]
	let fold = foldclosed(lineno)

	ruby rb_show_view_magic(VIM::evaluate('line'), VIM::evaluate('lineno'), VIM::evaluate('fold'))
endfunction

function! s:show_view_attachment()
	let line = getline(".")
	ruby rb_show_view_attachment(VIM::evaluate('line'))
endfunction

function! s:show_extract_msg()
	let line = getline(".")
	ruby rb_show_extract_msg(VIM::evaluate('line'))
endfunction

function! s:show_open_uri()
	let line = getline(".")
	let pos = getpos(".")
	let col = pos[2]

	ruby rb_show_open_uri(VIM::evaluate('line'), VIM::evaluate('col') - 1)
endfunction

function! s:show_open_msg()
ruby << EOF
	m = get_message
	mbox = File.expand_path('~/.notmuch/vim_mbox')
	cmd = VIM::evaluate('g:notmuch_reader') % mbox
	system "notmuch show --format=mbox id:#{m.message_id} > #{mbox} && #{cmd}"
EOF
endfunction

function! s:show_save_msg()
	let file = input('File name: ')
ruby << EOF
	file = VIM::evaluate('file')
	m = get_message
	system "notmuch show --format=mbox id:#{m.message_id} > #{file}"
EOF
endfunction

function! s:show_save_patches()
	let dir = input('Save to directory: ', getcwd(), 'dir')
	ruby rb_show_save_patches(VIM::evaluate('dir'))
endfunction

function! s:show_tag(intags)
	if empty(a:intags)
		let tags = input('tags: ')
	else
		let tags = a:intags
	endif
	ruby do_tag(get_cur_view, VIM::evaluate('l:tags'))
	call s:show_next_thread()
endfunction

function! s:search_search_prompt()
	let text = input('Search: ')
	if text == ""
	  return
	endif
	setlocal modifiable
ruby << EOF
	$cur_search = VIM::evaluate('text')
	$curbuf.reopen
	search_render($cur_search)
EOF
	setlocal nomodifiable
endfunction

function! s:search_info()
	ruby vim_puts get_thread_id
endfunction

function! s:search_refresh()
	setlocal modifiable
	ruby $curbuf.reopen
	ruby search_render($cur_search)
	setlocal nomodifiable
endfunction

function! s:search_tag(intags)
	if empty(a:intags)
		let tags = input('tags: ')
	else
		let tags = a:intags
	endif
	ruby do_tag(get_thread_id, VIM::evaluate('l:tags'))
	norm j
endfunction

function! s:search_tag_all(intags)
	if empty(a:intags)
		let tags = input('tags: ')
	else
		let tags = a:intags
	endif
	ruby do_tag($cur_search, VIM::evaluate('l:tags'))
	echo 'Tagged all search results with '.a:intags
endfunction

function! s:folders_search_prompt()
	let text = input('Search: ')
	call s:search(text)
endfunction

function! s:folders_refresh()
	setlocal modifiable
	ruby $curbuf.reopen
	ruby folders_render()
	setlocal nomodifiable
endfunction

"" basic

function! s:show_cursor_moved()
ruby << EOF
	if $render.is_ready?
		VIM::command('setlocal modifiable')
		$render.do_next
		VIM::command('setlocal nomodifiable')
	end
EOF
endfunction

function! s:show_next_thread()
	call s:kill_this_buffer()
	if line('.') != line('$')
		norm j
		call s:search_show_thread(0)
	else
		echo 'No more messages.'
	endif
endfunction

function! s:kill_this_buffer()
ruby << EOF
	$curbuf.close
	VIM::command("bdelete!")
EOF
endfunction

function! s:set_map(maps)
	nmapclear <buffer>
	for [key, code] in items(a:maps)
		let cmd = printf(":call <SID>%s<CR>", code)
		exec printf('nnoremap <buffer> %s %s', key, cmd)
	endfor
endfunction

function! s:new_buffer(type)
	enew
	setlocal buftype=nofile bufhidden=hide
	keepjumps 0d
	execute printf('set filetype=notmuch-%s', a:type)
	execute printf('set syntax=notmuch-%s', a:type)
	ruby $curbuf.init(VIM::evaluate('a:type'))
endfunction

function! s:set_menu_buffer()
	setlocal nomodifiable
	setlocal cursorline
	setlocal nowrap
endfunction

"" main

function! s:show(thread_id, msg_id)
	call s:new_buffer('show')
	setlocal modifiable

	ruby rb_show(VIM::evaluate('a:thread_id'), VIM::evaluate('a:msg_id'))

	setlocal nomodifiable
	setlocal foldmethod=manual
	call s:set_map(g:notmuch_show_maps)
endfunction

function! s:search_show_thread(mode)
	ruby rb_search_show_thread(VIM::evaluate('a:mode'))
endfunction

function! s:search(search)
	call s:new_buffer('search')
ruby << EOF
	$cur_search = VIM::evaluate('a:search')
	search_render($cur_search)
EOF
	call s:set_menu_buffer()
	call s:set_map(g:notmuch_search_maps)
	autocmd CursorMoved <buffer> call s:show_cursor_moved()
endfunction

function! s:folders_show_search()
ruby << EOF
	n = $curbuf.line_number
	s = $searches[n - 1]
	if s.length > 0
		VIM::command("call s:search('#{s}')")
	end
EOF
endfunction

function! s:folders_tag_all(tags)
ruby << EOF
	n = $curbuf.line_number
	s = $searches[n - 1]
	t = VIM::evaluate('a:tags')
	do_tag(s, t)
EOF
	call s:folders_refresh()
endfunction

function! s:folders()
	call s:new_buffer('folders')
	ruby folders_render()
	call s:set_menu_buffer()
	call s:set_map(g:notmuch_folders_maps)
	autocmd BufEnter,WinEnter,BufWinEnter <buffer>
		    \ call s:folders_refresh()
	augroup END
endfunction

"" root

function! s:set_defaults()
	if !exists('g:notmuch_save_sent_locally')
		let g:notmuch_save_sent_locally = s:notmuch_save_sent_locally_default
	endif

	if !exists('g:notmuch_save_sent_mailbox')
		let g:notmuch_save_sent_mailbox = s:notmuch_save_sent_mailbox_default
	endif

	if !exists('g:notmuch_date_format')
		let g:notmuch_date_format = s:notmuch_date_format_default
	endif

	if !exists('g:notmuch_datetime_format')
		let g:notmuch_datetime_format = s:notmuch_datetime_format_default
	endif

	if !exists('g:notmuch_open_uri')
		let g:notmuch_open_uri = s:notmuch_open_uri_default
	endif

	if !exists('g:notmuch_reader')
		let g:notmuch_reader = s:notmuch_reader_default
	endif

	if !exists('g:notmuch_sendmail')
		let g:notmuch_sendmail = s:notmuch_sendmail_default
	endif

	if !exists('g:notmuch_attachment_tmpdir')
		let g:notmuch_attachment_tmpdir = s:notmuch_attachment_tmpdir_default
	endif

	if !exists('g:notmuch_view_attachment')
		let g:notmuch_view_attachment = s:notmuch_view_attachment_default
	endif

	if !exists('g:notmuch_folders_count_threads')
		let g:notmuch_folders_count_threads = s:notmuch_folders_count_threads_default
	endif

	if !exists('g:notmuch_compose_start_insert')
		let g:notmuch_compose_start_insert = s:notmuch_compose_start_insert_default
	endif

	if !exists('g:notmuch_custom_search_maps') && exists('g:notmuch_rb_custom_search_maps')
		let g:notmuch_custom_search_maps = g:notmuch_rb_custom_search_maps
	endif

	if !exists('g:notmuch_custom_show_maps') && exists('g:notmuch_rb_custom_show_maps')
		let g:notmuch_custom_show_maps = g:notmuch_rb_custom_show_maps
	endif

	if exists('g:notmuch_custom_search_maps')
		call extend(g:notmuch_search_maps, g:notmuch_custom_search_maps)
	endif

	if exists('g:notmuch_custom_show_maps')
		call extend(g:notmuch_show_maps, g:notmuch_custom_show_maps)
	endif

	if !exists('g:notmuch_folders')
		let g:notmuch_folders = s:notmuch_folders_default
	endif

	if !exists('g:notmuch_show_headers')
		let g:notmuch_show_headers = s:notmuch_show_headers_default
	endif

	if !exists('g:notmuch_show_folded_threads')
		let g:notmuch_show_folded_threads = s:notmuch_show_folded_threads_default
	endif

	if !exists('g:notmuch_show_folded_full_headers')
		let g:notmuch_show_folded_full_headers = s:notmuch_show_folded_full_headers_default
	endif

	if !exists('g:notmuch_sendmail_method')
		let g:notmuch_sendmail_method = s:notmuch_sendmail_method_default
	endif

	if !exists('g:notmuch_sendmail_param')
		let g:notmuch_sendmail_param = s:notmuch_sendmail_param_default
	endif

endfunction

let s:plug = expand("<sfile>:h")
let s:script = s:plug . '/notmuch.rb'

function! s:NotMuch(...)
	call s:set_defaults()

ruby << EOF
	notmuch = VIM::evaluate('s:script')
	require notmuch
EOF

	if a:0
	  call s:search(join(a:000))
	else
	  call s:folders()
	endif
endfunction

command -nargs=* NotMuch call s:NotMuch(<f-args>)

" vim: set noexpandtab:
