if !isdir("images")
    mkdir("images")
    download("https://open.gl/content/code/sample.png", "images/kitten.png")
    download("https://open.gl/content/code/sample2.png", "images/puppy.png")
end
    
