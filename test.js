Printer = require("./lib/printer.js").Printer
p = new Printer('/dev/ttyAMA0')

p.print("hello\n\n\n")
