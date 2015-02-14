//
//  URLUtils.swift
//  Emergent
//
//  Created by Simon Gladman on 09/02/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
// TODO - make more robust to handle malformed URLs properly

import Foundation

class URLUtils
{
    
    class func createUrlFromGenomes(#redGenome : SwarmGenome, greenGenome: SwarmGenome, blueGenome: SwarmGenome) -> NSURL
    {
        let urlComponents = NSURLComponents()
        urlComponents.scheme = "emergent"
        
        let redQueryItem = NSURLQueryItem(name: "r", value: redGenome.toString())
        let greenQueryItem = NSURLQueryItem(name: "g", value: greenGenome.toString())
        let blueQueryItem = NSURLQueryItem(name: "b", value: blueGenome.toString())
        
        urlComponents.queryItems = [redQueryItem, greenQueryItem, blueQueryItem]
        
        return urlComponents.URL!
    }
    
    class func createGenomesFromURL(url: NSURL) -> (red: SwarmGenome, green: SwarmGenome, blue: SwarmGenome)?
    {
        var returnValue: (SwarmGenome, SwarmGenome, SwarmGenome)?
        
        let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
        var genomes = [SwarmGenome?](count: 3, repeatedValue: nil)
        
        if let queryItems = components?.queryItems as? [NSURLQueryItem]
        {
            for (idx: Int, component: NSURLQueryItem) in enumerate(queryItems)
            {
                genomes[idx] = SwarmGenome.fromString(component.value!)
            }
            
            returnValue = (genomes[0]!, genomes[1]!, genomes[2]!)
        }
        
        return returnValue
    }
    
}