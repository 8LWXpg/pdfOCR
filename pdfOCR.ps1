param (
    [Parameter(ValueFromPipeline = $true)]
    [System.IO.FileInfo]$pdf,
    [int]$spilt = 5
)

if ($pdf.Extension -ne '.pdf') {
    $pdf = Read-Host 'pdf path'
}

# get pdf pages
$pages = [Convert]::ToInt32( ((pdftk.exe $pdf dump_data_utf8 | Select-String 'NumberOfPages').ToString() -replace "[^0-9]", ''), 10)
if (!$?) {
    return
}

$TempFolder = "$env:temp\pdfOCR"
mkdir $TempFolder -Force | Out-Null

# change $spilt in case $pages < $spilt
$spilt = $spilt -gt $pages ? $pages : $spilt
0..($spilt - 1) | ForEach-Object -Parallel {
    $tiff = "$using:TempFolder\$($_.ToString()).tiff"
    # spilt pdf
    $a = ([math]::Round($using:pages / $using:spilt * $_) + 1).ToString()
    $b = [math]::Round($using:pages / $using:spilt * ($_ + 1)).ToString()
    "converting to tiff $_"
    gswin64c -q -dNOPAUSE -sDEVICE=tiffg4 "-dFirstPage=$a" "-dLastPage=$b" "-sOutputFile=$tiff" -r300 $using:pdf -c quit
    "OCRing $_"
    tesseract $tiff "$using:TempFolder\$($_.ToString())" -l eng -c textonly_pdf=1 pdf | Out-Null
}

# merge pdf and add bookmark back
$pdfs = @()
for ($i = 0; $i -lt $spilt; $i++) {
    $pdfs += "$TempFolder\$i.pdf"
}
pdftk $pdfs cat output "$TempFolder\out1.pdf"
pdftk "$TempFolder\out1.pdf" multibackground $pdf output "$TempFolder\out2.pdf"
pdftk $pdf dump_data_utf8 output - | pdftk.exe "$TempFolder\out2.pdf" update_info_utf8 - output "$($pdf.Remove($pdf.Length - 4))_OCR.pdf"
Remove-Item $TempFolder -Force -Recurse