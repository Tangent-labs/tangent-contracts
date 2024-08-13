import "../lib/forge-std/src/Script.sol";

contract CsvMaker is Script {
    string path;
    string line;

    constructor(string memory _path) {
        path = _path;
        vm.removeFile(path);
    }

    function addToLine(uint256 cell) external {
        string memory data = vm.toString(cell);
        // We add "xx" formating to avoid

        // data = string.concat('"', data);
        // data = string.concat(data, '"');
        line = string.concat(line, data);
        line = string.concat(line, ";");
    }

    function addToLine(string memory cell) external {
        line = string.concat(line, cell);
        line = string.concat(line, ";");
    }

    function writeLine(string memory _line) external {
        vm.writeLine(path, _line);
        line = "";
    }
    function writeCurrentLine() external {
        vm.writeLine(path, line);
        line = "";
    }
}
