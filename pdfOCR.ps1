param (
	[Parameter(ValueFromPipeline = $true)]
	[System.IO.FileInfo]$pdf,
	[int]$spilt = 5
)

while ($pdf.Extension -ne '.pdf') {
	$pdf = Read-Host 'pdf path'
}

# get pdf pages
$pages = [Convert]::ToInt32(((pdftk $pdf dump_data_utf8 | Select-String 'NumberOfPages').ToString() -replace "[^0-9]", ''), 10)
if (!$?) {
	return
}

[System.IO.FileInfo]$temp_folder = "$($pdf.DirectoryName)\temp_pdfOCR"
if ($temp_folder.Exists) {
	Remove-Item $temp_folder -Recurse -Force
}
mkdir $temp_folder -Force | Out-Null

# change $spilt in case $pages < $spilt
$spilt = $spilt -gt $pages ? $pages : $spilt
0..($spilt - 1) | ForEach-Object -Parallel {
	$temp_pdf = "$using:temp_folder\$_.pdf"
	# spilt pdf
	$a = [math]::Round($using:pages / $using:spilt * $_) + 1
	$b = [math]::Round($using:pages / $using:spilt * ($_ + 1))
	"OCRing $_"
	gswin64c -dNOPAUSE -dQUIET -q -sDEVICE=pdfocr24 -sOCRLanguage=eng "-sOutputFile=$temp_pdf" "-dFirstPage=$a" "-dLastPage=$b" -r300 $using:pdf -c quit
}

# merge pdf and add bookmark back
$pdfs = @()
for ($i = 0; $i -lt $spilt; $i++) {
	$pdfs += "$temp_folder\$i.pdf"
}
pdftk $pdfs cat output "$temp_folder\out1.pdf"
pdftk "$temp_folder\out1.pdf" multibackground $pdf output "$temp_folder\out2.pdf"
pdftk $pdf dump_data_utf8 output - | pdftk "$temp_folder\out2.pdf" update_info_utf8 - output "$($pdf.DirectoryName)\$($pdf.BaseName)_OCR.pdf"
if ($?) {
	Remove-Item $temp_folder -Force -Recurse
}