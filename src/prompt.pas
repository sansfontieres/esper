// Just fun throwaway code as my prompt
program prompt;

uses SysUtils, unix;

const reset_code: string = '%{' + #27 + '[0m%}';

var code: integer = 0;

function local_session(): boolean;
begin
    local_session := length(getEnvironmentVariable('SSH_CONNECTION')) = 0;
end;

function rel_home(homedir, cwd: string): boolean;
var i: integer;
begin
    if length(homedir) <= length(cwd) then i := compareStr(homedir, copy(cwd, 0, length(homedir)));
    if i = 0 then rel_home := true else rel_home := false;
end;

procedure print_path();
var
    homedir: string;
    path: string;
begin
    homedir := getEnvironmentVariable('HOME');

    write('%{' + #27 + '[32m%}');

    if not local_session() then write(format('%s:', [getHostName]));

    if rel_home(homedir, getCurrentDir) then
        path := '~' + copy(getCurrentDir, length(homedir) + 1, length(getCurrentDir))
    else
        path := getCurrentDir;

    write(path + reset_code);
end;

procedure print_prompt(code: integer);
begin
    if code = 0 then
        write('; ')
    else
        write('%{' + #27 + '[31m%};' + reset_code + ' ');
end;

begin
    if argv[1] <> nil then code := strToInt(argv[1]);
    print_path();
    print_prompt(code);
end.
