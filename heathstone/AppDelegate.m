//
//  AppDelegate.m
//  heathstone
//
//  Created by Andy Dremeaux on 9/8/14.
//  Copyright (c) 2014 Andy Dremeaux. All rights reserved.
//

#import "AppDelegate.h"

#define TOTAL 203
#define LEGEND 21
#define EPIC 33
#define RARE 67
#define COMMON 82
#define TRIALS 1500

//types are additive for efficiency
#define CHANCE_LEGEND 0.01194f
#define CHANCE_EPIC 0.05786f
#define CHANCE_RARE 0.28548f

#define GLEGEND 0.0929f
#define GEPIC 0.0671f
#define GRARE 0.06033f
#define GCOMMON 0.02057f


#define DEBUG_LOGS NO
#define MAIN_LOGS NO

typedef enum {
	typeCommon = 5,
	typeGCommon = 50,
	typeRare = 20,
	typeGRare = 100,
	typeEpic = 100,
	typeGEpic = 400,
	typeLegend = 400,
	typeGLegend = 1600
} CardType;

typedef enum {
	costCommon = 40,
	costRare = 100,
	costEpic = 400,
	costLegend = 1600
} DustCost;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	float average = 0;
	float goldsAverage = 0;

	for (int trialNum = 0; trialNum < TRIALS; trialNum++) {
		if (trialNum % 100 == 0) NSLog(@"trial %d", trialNum);
		
		int dust = 0;
		int packsOpened = 0;
		int goldsOpened = 0;
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		if (DEBUG_LOGS) NSLog(@"dust left: %d of %d", dust, [self remainingDust:dict]);
		
		while (YES) {
			NSArray *pack = [self openPack];
			packsOpened++;
			for (NSNumber *n in pack) {
				int nInt = [n intValue];
				NSNumber *realVal = n;
				BOOL isGold = NO;
				
				if (nInt >= TOTAL) {
					isGold = YES;
					nInt -= TOTAL;
					realVal = @(nInt);
					goldsOpened++;
				}
				
				if (!dict[realVal]) {
					dict[realVal] = @1;
				} else if ([self cardType:nInt] == typeLegend) {
					dust += isGold ? typeGLegend : typeLegend;
				} else if ([dict[realVal] intValue] == 2) {
					dust += [self cardType:[n intValue]];
				} else {
					dict[realVal] = @2;
				}
				
			}
			if (DEBUG_LOGS) NSLog(@"opened pack %@", [pack componentsJoinedByString:@","]);
			
			if ([self packComplete:dict] || [self remainingDust:dict] <= dust) {
				average = ((average * trialNum) + packsOpened) / (trialNum + 1);
				goldsAverage = ((goldsAverage * trialNum) + goldsOpened) / (trialNum + 1);
				
				int dustReq = [self remainingDust:dict];
//				for (NSObject *key in [dict allKeys]) {
//					NSNumber *n = (NSNumber *)key;
//					int thisDust = [self cardType:[n intValue]];
//					NSLog(@"%d: %d - %d", [n intValue], [dict[key] intValue], thisDust);
//				}
				if (MAIN_LOGS) {
					NSLog(@"dust: %d of %d", dust, dustReq);
					NSLog(@"set complete with %d packs opened, %d golds", packsOpened, goldsOpened);
				}
				break;
			} else {
				if (DEBUG_LOGS) NSLog(@"dust left: %d of %d", dust, [self remainingDust:dict]);
			}
		}
	}
	
	NSLog(@"average packs opened: %f", average);
	NSLog(@"gold cards average: %f", goldsAverage);
	NSLog(@"---");
}

- (NSArray *)openPack {
	int cardsPerPack = 5;
	NSMutableArray *cards = [[NSMutableArray alloc] init];
	for (int i = 0; i < cardsPerPack; i++) {
		double val = ((double)arc4random() / 0x100000000);
		double goldVal = ((double)arc4random() / 0x100000000);
		int card;
		BOOL isGold = NO;
		if (val < CHANCE_LEGEND) {
			card = arc4random_uniform(LEGEND);
			if (goldVal < GLEGEND) isGold = YES;
		} else if (val < CHANCE_EPIC) {
			card = arc4random_uniform(EPIC) + LEGEND;
			if (goldVal < GEPIC) isGold = YES;
		} else if (val < CHANCE_RARE) {
			card = arc4random_uniform(RARE) + LEGEND + EPIC;
			if (goldVal < GRARE) isGold = YES;
		} else {
			card = arc4random_uniform(COMMON) + LEGEND + EPIC + RARE;
			if (goldVal < GCOMMON) isGold = YES;
		}
		
		if (isGold) card += TOTAL;
		if (DEBUG_LOGS) NSLog(@"val %f card %d -- %f", val, card, goldVal);
		
		[cards addObject:@(card)];
	}
	return cards;
}

- (CardType)cardType:(int)val {
	BOOL isGold = NO;
	if (val >= TOTAL) {
		isGold = YES;
		val -= TOTAL;
	}
	
	CardType type = typeCommon;
	if (val < LEGEND) type = typeLegend;
	else if (val < LEGEND + EPIC) type = typeEpic;
	else if (val < LEGEND + EPIC + RARE) type = typeRare;

	if (!isGold) return type;
	
	switch (type) {
		case typeCommon: return typeGCommon; break;
		case typeRare: return typeGRare; break;
		case typeEpic: return typeGEpic; break;
		case typeLegend: return typeGLegend; break;
		default: @throw [NSException exceptionWithName:@"blah" reason:@"bad type" userInfo:@{@"type": @(type)}]; break;
	}
}

- (BOOL)packComplete:(NSDictionary *)dict {
	for (int i = 0; i < TOTAL; i++) {
		NSNumber *n = dict[@(i)];
		if (!n) return NO;
		if ([self cardType:i] != typeLegend)
			if ([n intValue] != 2)
				return NO;
	}
	return YES;
}

- (int)remainingDust:(NSDictionary *)dict {
	int total = 0;
	for (int i = 0; i < TOTAL; i++) {
		NSNumber *n = dict[@(i)];
		CardType type = [self cardType:i];
		int cost = [self dustCostForType:type];
		if (!n) {
			if (type == typeLegend)
				total += cost;
			else
				total += (cost * 2);
		} else if ([n intValue] == 1) {
			if (type != typeLegend)
				total += cost;
		}
	}
	return total;
}

- (int)dustCostForType:(CardType)type {
	switch (type) {
		case typeCommon: return costCommon; break;
		case typeRare: return costRare; break;
		case typeEpic: return costEpic; break;
		case typeLegend: default: return costLegend; break;
	}
	return 0;
}

@end
