function hdr = eegEnobioReaderHeaderFile(file_info)

      txt = fileread(file_info);
      hdr = eegEnobioReaderHeader(txt);
      
end


