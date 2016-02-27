image_path = Pkg.dir("GLAbstraction", "tutorials", "images")
if !isdir(image_path)
    mkdir(image_path)
    download("https://open.gl/content/code/sample.png", joinpath(image_path, "kitten.png"))
    download("https://open.gl/content/code/sample2.png", joinpath(image_path, "puppy.png"))
end
