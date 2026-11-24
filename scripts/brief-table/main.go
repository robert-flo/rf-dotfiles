package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/table"
)

func main() {
	cols := flag.String("c", "", "column headers, comma-separated")
	widths := flag.String("w", "", "column widths, comma-separated")
	total := flag.Int("W", 0, "total table width")
	border := flag.String("b", "rounded", "border: rounded|normal")
	file := flag.String("f", "", "TSV file (last column is URL, not shown)")
	indent := flag.String("indent", "", "prefix each output line")
	flag.Parse()

	headers := splitComma(*cols)
	colW := parseInts(*widths)

	in, closer, err := openInput(*file)
	if err != nil {
		fmt.Fprintf(os.Stderr, "brief-table: %v\n", err)
		os.Exit(1)
	}
	if closer != nil {
		defer closer()
	}

	rows, urls, err := readTSV(in)
	if err != nil {
		fmt.Fprintf(os.Stderr, "brief-table: %v\n", err)
		os.Exit(1)
	}
	if len(rows) == 0 {
		return
	}

	link := wantLinks()
	for i := range rows {
		if link && i < len(urls) && urls[i] != "" && len(rows[i]) > 0 {
			rows[i][0] = osc8(urls[i], rows[i][0])
		}
	}

	b := lipgloss.RoundedBorder()
	if *border == "normal" || os.Getenv("NO_COLOR") != "" {
		b = lipgloss.NormalBorder()
	}

	t := table.New().
		Border(b).
		Headers(headers...).
		Rows(rows...).
		StyleFunc(func(_ int, col int) lipgloss.Style {
			st := lipgloss.NewStyle()
			if col < len(colW) && colW[col] > 0 {
				st = st.Width(colW[col])
			}
			return st
		})
	if *total > 0 {
		t = t.Width(*total)
	}

	out := t.String()
	if *indent != "" {
		var bld strings.Builder
		for _, line := range strings.Split(out, "\n") {
			if line == "" {
				bld.WriteByte('\n')
				continue
			}
			bld.WriteString(*indent)
			bld.WriteString(line)
			bld.WriteByte('\n')
		}
		out = strings.TrimRight(bld.String(), "\n")
	}
	fmt.Println(out)
}

func openInput(path string) (io.Reader, func(), error) {
	if path == "" || path == "-" {
		return os.Stdin, nil, nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	return f, func() { _ = f.Close() }, nil
}

func readTSV(r io.Reader) ([][]string, []string, error) {
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	var rows [][]string
	var urls []string
	for sc.Scan() {
		line := sc.Text()
		if line == "" {
			continue
		}
		parts := strings.Split(line, "\t")
		url := ""
		if len(parts) >= 4 {
			url = parts[len(parts)-1]
			parts = parts[:len(parts)-1]
		}
		rows = append(rows, parts)
		urls = append(urls, url)
	}
	if err := sc.Err(); err != nil {
		return nil, nil, err
	}
	return rows, urls, nil
}

func splitComma(s string) []string {
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func parseInts(s string) []int {
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	out := make([]int, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		n, err := strconv.Atoi(p)
		if err != nil {
			n = 0
		}
		out = append(out, n)
	}
	return out
}

// OSC-8 (ECMA-48): ST via ESC\ for lipgloss width; BEL is wider but breaks some tables.
func osc8(url, text string) string {
	return "\x1b]8;;" + url + "\x1b\\" + text + "\x1b]8;;\x1b\\"
}

func wantLinks() bool {
	if os.Getenv("NO_COLOR") != "" || os.Getenv("GH_BRIEF_NO_LINKS") != "" {
		return false
	}
	st, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return st.Mode()&os.ModeCharDevice != 0
}
