param (
	[Parameter(ValueFromPipeline = $true, Mandatory)]
	[string]$pdf,
	[int]$thread = 5
)
[System.IO.FileInfo]$pdf = (Resolve-Path $pdf).Path

if (!$pdf.Exists -or $pdf.Extension -ne '.pdf') {
	Write-Error 'pdf not found' -Category OpenError
	exit
}

# get pdf pages
$pages = (pdftk $pdf dump_data | Select-String 'NumberOfPages: (\d+)').Matches.Groups[1].Value.ToInt32($null)
if (!$pages) {
	exit
}

[System.IO.FileInfo]$temp_folder = "$($pdf.DirectoryName)\temp_pdfOCR"
if ($temp_folder.Exists) {
	Remove-Item $temp_folder -Recurse -Force
}
mkdir $temp_folder -Force | Out-Null

# change $thread in case $pages < $thread
$thread = $thread -gt $pages ? $pages : $thread
0..($thread - 1) | ForEach-Object -Parallel {
	$temp_pdf = "$using:temp_folder\$_.pdf"
	# spilt pdf
	$a = [math]::Round($using:pages / $using:thread * $_) + 1
	$b = [math]::Round($using:pages / $using:thread * ($_ + 1))
	"OCR $_"
	gswin64c -q -sDEVICE=pdfocr24 -sOCRLanguage=eng "-dFirstPage=$a" "-dLastPage=$b" -r300 -o $temp_pdf $using:pdf
	if (!$?) {
		exit
	}
}

# merge pdf and add bookmark back
[System.IO.FileInfo]$out_pdf = "$($pdf.DirectoryName)\$($pdf.BaseName)_OCR.pdf"
if ($out_pdf.Exists) {
	Remove-Item $out_pdf -Force
}
$pdfs = @(for ($i = 0; $i -lt $thread; $i++) {
		"$temp_folder\$i.pdf"
	})
pdftk $pdfs cat output "$temp_folder\out.pdf"
pdftk $pdf dump_data_utf8 output - |
	pdftk "$temp_folder\out.pdf" update_info_utf8 - output $out_pdf && `
	Remove-Item $temp_folder -Force -Recurse