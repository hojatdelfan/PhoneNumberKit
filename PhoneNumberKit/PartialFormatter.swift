//
//  PartialFormatter.swift
//  PhoneNumberKit
//
//  Created by Roy Marmelstein on 29/11/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation

public class PartialFormatter {
    
    let metadata = Metadata.sharedInstance
    let parser = PhoneNumberParser()
    let regex = RegularExpressions.sharedInstance
    
    let defaultRegion: String
    let defaultMetadata: MetadataTerritory?

    var currentMetadata: MetadataTerritory?
    var prefixBeforeNationalNumber =  String()
    var shouldAddSpaceAfterNationalPrefix = false

    //MARK: Lifecycle
    
    convenience init() {
        let region = PhoneNumberKit().defaultRegionCode()
        self.init(region: region)
    }
    
    init(region: String) {
        defaultRegion = region
        defaultMetadata = metadata.fetchMetadataForCountry(defaultRegion)
        currentMetadata = defaultMetadata
    }
    
    func formatPartial(rawNumber: String) -> String {
        if rawNumber.isEmpty || rawNumber.characters.count < 3 {
            return rawNumber
        }
        currentMetadata = defaultMetadata
        prefixBeforeNationalNumber = String()
        let iddFreeNumber = self.attemptToExtractIDD(rawNumber)
        let normalizedNumber = self.parser.normalizePhoneNumber(iddFreeNumber)
        var nationalNumber = self.attemptToExtractCountryCallingCode(normalizedNumber)
        if let formats = self.getAvailableFormats() {
            nationalNumber = self.attemptToFormat(nationalNumber, formats: formats)
        }
        var finalNumber = String()
        if prefixBeforeNationalNumber.characters.count > 0 {
            finalNumber.appendContentsOf(prefixBeforeNationalNumber)
        }
        if nationalNumber.characters.count > 0 {
            finalNumber.appendContentsOf(nationalNumber)
        }
        return finalNumber
    }
    
    func attemptToExtractIDD(rawNumber: String) -> String {
        var processedNumber = rawNumber
        do {
            if let internationalPrefix = currentMetadata?.internationalPrefix {
                let prefixPattern = String(format: iddPattern, arguments: [internationalPrefix])
                let matches = try regex.matchedStringByRegex(prefixPattern, string: rawNumber)
                if let m = matches.first {
                    let startCallingCode = m.characters.count
                    let index = rawNumber.startIndex.advancedBy(startCallingCode)
                    processedNumber = rawNumber.substringFromIndex(index)
                    prefixBeforeNationalNumber = rawNumber.substringToIndex(index)
                    if rawNumber.characters.first != "+" {
                        prefixBeforeNationalNumber.appendContentsOf(" ")
                    }
                }
            }
        }
        catch {
            return processedNumber
        }
        return processedNumber
    }
    
    func attemptToExtractCountryCallingCode(rawNumber: String) -> String {
        var processedNumber = rawNumber
        if rawNumber.isEmpty {
            return rawNumber
        }
        var numberWithoutCountryCallingCode = String()
        if let potentialCountryCode = self.parser.extractPotentialCountryCode(rawNumber, nationalNumber: &numberWithoutCountryCallingCode) where potentialCountryCode != 0 {
            processedNumber = numberWithoutCountryCallingCode
            currentMetadata = metadata.fetchMainCountryMetadataForCode(potentialCountryCode)
            prefixBeforeNationalNumber.appendContentsOf("\(potentialCountryCode) ")
        }
        return processedNumber
    }

    func getAvailableFormats() -> [MetadataPhoneNumberFormat]? {
        var possibleFormats = [MetadataPhoneNumberFormat]()
        if let metadata = currentMetadata {
            let formatList = metadata.numberFormats
            for format in formatList {
                if isFormatEligible(format) {
                    possibleFormats.append(format)
                }
            }
            return possibleFormats
        }
        return nil
    }
    
    func isFormatEligible(format: MetadataPhoneNumberFormat) -> Bool {
        guard let pattern = format.pattern else {
            return false
        }
        do {
            let fallBackMatches = try regex.regexMatches(eligibleAsYouTypePattern, string: pattern)
            return (fallBackMatches.count == 0)
        }
        catch {
            return false
        }
    }
    
    func attemptToFormat(rawNumber: String, formats: [MetadataPhoneNumberFormat]) -> String {
        for format in formats {
            if let pattern = format.pattern, let formatTemplate = format.format {
                let patternRegExp = String(format: formatPattern, arguments: [pattern])
                do {
                    let matches = try regex.regexMatches(patternRegExp, string: rawNumber)
                    if matches.count > 0 {
                        if let nationalPrefixFormattingRule = format.nationalPrefixFormattingRule {
                            let separatorRegex = try regex.regexWithPattern(prefixSeparatorPattern)
                            let nationalPrefixMatches = separatorRegex.matchesInString(nationalPrefixFormattingRule, options: [], range:  NSMakeRange(0, nationalPrefixFormattingRule.characters.count))
                            if nationalPrefixMatches.count > 0 {
                                shouldAddSpaceAfterNationalPrefix = true
                            }
                        }
                        let formattedNumber = regex.replaceStringByRegex(pattern, string: rawNumber, template: formatTemplate)
                        return formattedNumber
                    }
                }
                catch {
                
                }
            }
        }
        return rawNumber
    }
}