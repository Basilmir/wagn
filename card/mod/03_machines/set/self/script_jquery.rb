
view :raw do |args|
  File.read "#{Cardio.gem_root}/mod/03_machines/lib/javascript/jquery.js"
end

view :editor do |args|
  "Content is stored in file and can't be edited."
end
